# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents an explicit transaction
    class Transaction
      attr_reader :connection

      def initialize(connection, session, bookmarks = [], options = {}, on_release: nil)
        @connection = connection
        @session = session
        @options = options
        @on_release = on_release  # called once when the connection is no longer needed
        @open = true
        @committed = false
        @rolled_back = false
        @failed = false
        @current_result = nil

        # Begin the transaction
        # Drop blank values so the serialised BEGIN map matches what
        # testkit's stub scripts expect (e.g. `BEGIN {"db": "adb"}`,
        # not `BEGIN {"db": "adb", "tx_metadata": {}}`).
        begin_extra = {
          bookmarks: bookmarks,
          db: options[:database],
          mode: options[:access_mode],
          tx_timeout: options[:timeout],
          tx_metadata: options[:metadata],
          imp_user: options[:impersonated_user]
        }
        begin_extra.reject!(&Internal::Extras::BLANK)

        @connection.send_message(@connection.protocol.build_begin(begin_extra))
        @connection.flush

        @connection.fetch_response.assert_success!
      rescue Exceptions::Neo4jException => e
        # BEGIN failed — server is now in FAILED state. Clear it before
        # propagating so the connection is reusable by whoever is managing
        # this session's pool checkout.
        @connection.reset!
        @open = false
        release_connection
        raise @connection.classify_failure(e)
      rescue StandardError
        # Transport-level failure (IO/socket). RESET will likely fail
        # too on a dead connection, but release the lease so it doesn't
        # leak; pool reuse will surface the breakage to the next caller.
        @open = false
        release_connection
        raise
      end

      def run(query, **parameters)
        Internal::Validator.require_query_text!(query)
        raise Exceptions::ClientException, 'Cannot run more queries in this transaction, it has been rolled back' if @failed
        unless @open
          # Mirror the Java/JRuby messages so the closed-state reason
          # (committed vs rolled back) is reported the same on both impls.
          raise Exceptions::ClientException,
                "Cannot run more queries in this transaction, it has been #{@committed ? 'committed' : 'rolled back'}"
        end

        consume_current_result

        fetch_size = effective_fetch_size

        # send/flush are inside the begin block so a transport-level
        # failure surfacing on fetch_response still sets @failed and
        # goes through classify_failure. Connection#send_message and
        # #flush both defer peer-closed errors so a buffered server
        # FAILURE is read before fetch_response can raise its own
        # EOF-driven ServiceUnavailableException — JRuby surfaces
        # EPIPE eagerly, MRI tends to defer it naturally. Without
        # this rescue placement, session.close's subsequent rollback
        # path takes the ROLLBACK-message branch (rather than
        # rollback_via_reset) and re-fails on the dead connection.
        run_response =
          begin
            @connection.send_message(@connection.protocol.build_run(query, parameters, {}))
            @connection.send_message(@connection.protocol.build_pull(n: fetch_size))
            @connection.flush
            @connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException => e
            @failed = true
            raise @connection.classify_failure(e)
          end

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)

        @current_result = Result.new(@connection, keys, query_text: query, parameters: parameters,
                                     run_metadata: run_response.metadata, fetch_size: fetch_size)
      end

      def commit
        # Java/JRuby-aligned messages for the already-closed states.
        raise Exceptions::ClientException, 'Can\'t commit, transaction has been committed' if @committed
        raise Exceptions::ClientException, 'Can\'t commit, transaction has been rolled back' if @rolled_back
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open

        if @failed
          rollback_via_reset
          raise Exceptions::ClientException, "Transaction can't be committed. It has been rolled back"
        end

        begin
          consume_current_result(discard: true)
        rescue Exceptions::Neo4jException
          rollback_via_reset
          raise
        end

        # send/flush inside the begin block — see Transaction#run for
        # the rationale on JRuby vs MRI socket-write timing.
        response =
          begin
            @connection.send_message(Bolt::Message.commit)
            @connection.flush
            @connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException => e
            @failed = true
            rollback_via_reset
            raise @connection.classify_failure(e)
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
          consume_current_result(discard: true)
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
          @connection.fetch_response.assert_success!
        rescue Exceptions::ServiceUnavailableException, Exceptions::SessionExpiredException
          # Rolling back on a broken/dead connection is a no-op — the
          # server discards the tx when the link dies. Swallow these so
          # session.close's rollback path stays clean.
        rescue Exceptions::Neo4jException => e
          # A server FAILURE on ROLLBACK (e.g. DatabaseUnavailable) is a
          # real error: the connection is now in FAILED state. RESET it
          # back to READY, then surface the failure through the routing
          # classifier — same as commit/run — so routing side effects
          # (e.g. deactivate on DatabaseUnavailable) fire and the surfaced
          # type is consistent. No-op for direct connections.
          @connection.reset!
          raise @connection.classify_failure(e)
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

      # See Session#effective_fetch_size. Transactions inherit the session
      # options at open, so the same default rules apply.
      def effective_fetch_size
        size = @options[:fetch_size]
        size.nil? ? 1000 : size
      end

      # On a new RUN in the same tx the previous result is buffered so it
      # stays accessible; at tx end (commit/rollback) it goes out of
      # scope, so discard it instead — DISCARD abandons remaining records
      # (essential when the result is unbounded) rather than streaming
      # them all into memory, and leaves it raising ResultConsumedException
      # on later access.
      def consume_current_result(discard: false)
        return unless @current_result

        begin
          discard ? @current_result.consume : @current_result.buffer
        rescue Exceptions::Neo4jException => e
          @failed = true
          # A wire error during PULL streaming (e.g. a reader connection
          # interrupted mid-stream) raises ServiceUnavailable straight
          # from fetch_response, not via Result#on_failure — so it never
          # saw the routing classifier. Run it through here so a routed
          # connection failure surfaces as SessionExpired (idempotent if
          # already classified).
          raise @connection.classify_failure(e)
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
