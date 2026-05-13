# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents an explicit transaction
    class Transaction
      attr_reader :connection

      def initialize(connection, session, bookmarks = [], options = {}, on_release: nil)
        @connection = connection
        @session = session
        @on_release = on_release  # called once when the connection is no longer needed
        @open = true
        @committed = false
        @rolled_back = false
        @failed = false
        @current_result = nil

        # Begin the transaction
        begin_extra = {}
        begin_extra[:bookmarks] = bookmarks if bookmarks&.any?
        begin_extra[:db] = options[:database] if options[:database]
        begin_extra[:mode] = options[:access_mode] if options[:access_mode]
        begin_extra[:tx_timeout] = options[:timeout] if options[:timeout]
        begin_extra[:tx_metadata] = options[:metadata] if options[:metadata]

        @connection.send_message(Bolt::Message.begin_transaction(begin_extra))
        @connection.flush

        @connection.fetch_response.assert_success!
      rescue Exceptions::Neo4jException
        # BEGIN failed — server is now in FAILED state. Clear it before
        # propagating so the connection is reusable by whoever is managing
        # this session's pool checkout.
        @connection.reset!
        @open = false
        release_connection
        raise
      rescue StandardError
        # Transport-level failure (IO/socket). RESET will likely fail
        # too on a dead connection, but release the lease so it doesn't
        # leak; pool reuse will surface the breakage to the next caller.
        @open = false
        release_connection
        raise
      end

      def run(query, **parameters)
        raise Exceptions::ClientException, 'Cannot run more queries in this transaction, it has been rolled back' if @failed
        raise Exceptions::ClientException, 'Transaction is closed' unless @open

        consume_current_result

        @connection.send_message(Bolt::Message.run(query, parameters))
        @connection.send_message(Bolt::Message.pull)
        @connection.flush

        run_response =
          begin
            @connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException
            @failed = true
            raise
          end

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)

        @current_result = Result.new(@connection, keys, query_text: query, parameters: parameters, run_metadata: run_response.metadata)
      end

      def commit
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open
        raise Exceptions::ClientException, 'Transaction is already committed' if @committed

        if @failed
          rollback_via_reset
          raise Exceptions::ClientException, "Transaction can't be committed. It has been rolled back"
        end

        begin
          consume_current_result
        rescue Exceptions::Neo4jException
          rollback_via_reset
          raise
        end

        @connection.send_message(Bolt::Message.commit)
        @connection.flush

        response =
          begin
            @connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException
            @failed = true
            rollback_via_reset
            raise
          end

        @committed = true
        @open = false

        bookmarks = response.metadata[:bookmark]
        @session.update_bookmarks(bookmarks) if bookmarks
        release_connection
      end

      def rollback
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open

        begin
          consume_current_result
        rescue Exceptions::Neo4jException
          # Failures surfaced while draining a pending result are expected
          # during rollback — the tx is being discarded anyway. @failed is
          # set; RESET path below will clean up the connection.
        end

        if @failed
          rollback_via_reset
          return
        end

        begin
          @connection.send_message(Bolt::Message.rollback)
          @connection.flush
          @connection.fetch_response
        ensure
          @rolled_back = true
          @open = false
          release_connection
        end
      end

      def close
        rollback if @open && !@committed
      end

      def open?
        @open
      end

      def failed?
        @failed
      end

      private

      def consume_current_result
        return unless @current_result

        begin
          @current_result.buffer
        rescue Exceptions::Neo4jException
          @failed = true
          raise
        end

        # buffer is a no-op when the result was already consumed by the
        # user; surface any stored failure so callers can react.
        @failed = true if @current_result.failed?
      end

      # Recover a failed transaction by asking the server to RESET the
      # connection. RESET transitions the server from FAILED back to READY
      # and implicitly rolls back the open transaction.
      def rollback_via_reset
        @connection.reset!
        @rolled_back = true
        @open = false
        release_connection
      end

      def release_connection
        @on_release&.call
        @on_release = nil  # idempotent
      end
    end
  end
end
