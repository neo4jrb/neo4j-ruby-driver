# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents an explicit transaction
    class Transaction
      def initialize(connection, session, bookmarks = [], options = {})
        @connection = connection
        @session = session
        @open = true
        @committed = false
        @rolled_back = false
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

        response = @connection.fetch_response
        unless response.is_a?(Bolt::Message::Success)
          handle_response_error(response)
        end
      end

      def run(query, parameters = {})
        raise Exceptions::ClientException, 'Transaction is closed' unless @open

        # Auto-consume any previous unconsumed result
        @current_result&.consume rescue nil

        @connection.send_message(Bolt::Message.run(query, parameters))
        @connection.send_message(Bolt::Message.pull)
        @connection.flush

        # Get RUN response (should be SUCCESS with keys)
        run_response = @connection.fetch_response

        unless run_response.is_a?(Bolt::Message::Success)
          handle_response_error(run_response)
        end

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)

        # Return result that will fetch RECORD responses and final summary
        @current_result = Result.new(@connection, keys, query_text: query, parameters: parameters, run_metadata: run_response.metadata)
      end

      def commit
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open
        raise Exceptions::ClientException, 'Transaction is already committed' if @committed

        # Consume any unconsumed results before committing
        @current_result&.consume rescue nil

        @connection.send_message(Bolt::Message.commit)
        @connection.flush

        response = @connection.fetch_response

        unless response.is_a?(Bolt::Message::Success)
          handle_response_error(response)
        end

        @committed = true
        @open = false

        # Extract bookmark if present
        bookmarks = response.metadata[:bookmark]
        @session.update_bookmarks(bookmarks) if bookmarks
      end

      def rollback
        return unless @open
        raise Exceptions::ClientException, 'Transaction is already committed' if @committed

        begin
          @connection.send_message(Bolt::Message.rollback)
          @connection.flush
          @connection.fetch_response
        ensure
          @rolled_back = true
          @open = false
        end
      end

      def close
        rollback if @open && !@committed
      end

      def open?
        @open
      end

      private

      def handle_response_error(response)
        if response.is_a?(Bolt::Message::Failure)
          code = response.code
          message = response.message

          exception_class = determine_exception_class(code)
          raise exception_class.new(message, code: code)
        else
          raise Exceptions::ClientException, "Unexpected response: #{response.class}"
        end
      end

      def determine_exception_class(code)
        case code
        when /^Neo\.ClientError\.Security\.Unauthorized/
          Exceptions::AuthenticationException
        when /^Neo\.ClientError\.Security/
          Exceptions::SecurityException
        when /^Neo\.ClientError/
          Exceptions::ClientException
        when /^Neo\.TransientError/
          Exceptions::TransientException
        else
          Exceptions::DatabaseException
        end
      end
    end
  end
end
