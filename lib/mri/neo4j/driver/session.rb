# frozen_string_literal: true

module Neo4j
  module Driver
    # Per-operation connection acquisition: each `run` / `begin_transaction` /
    # `execute_read` / `execute_write` acquires a fresh connection from the
    # driver with that operation's access mode and database, and releases it
    # back to the pool when the operation completes (Result fully consumed,
    # or transaction committed/rolled back). The session itself does not
    # hold a connection — only its in-flight operation does.
    class Session
      def initialize(connection_provider, options = {})
        @connection_provider = connection_provider
        @options = options
        @transaction = nil
        @open = true
        @last_bookmarks = Set.new
        @current_result = nil

        # Initialize with provided bookmarks if any
        if options[:bookmarks]
          initial_bookmarks = options[:bookmarks]
          initial_bookmarks = [initial_bookmarks] unless initial_bookmarks.is_a?(Enumerable)
          initial_bookmarks.each do |bookmark|
            @last_bookmarks << (bookmark.is_a?(Bookmark) ? bookmark : Bookmark.new(bookmark))
          end
        end
      end

      def run(query, parameters = {}, config = {})
        parameters ||= {}

        unless parameters.is_a?(Hash)
          raise ArgumentError,
                "The parameters should be provided as Map type. Unsupported parameters type: #{parameters.class}"
        end

        raise Exceptions::ClientException, 'Session is closed' unless @open
        raise Exceptions::ClientException, 'You cannot run a query directly on a session while a transaction is open' if @transaction&.open?

        drain_current_result

        timeout = config.delete(:timeout)
        tx_metadata = config.delete(:metadata)

        # `mode` is sent for read sessions (matches routing-server
        # expectations); writers are the default and omit the field.
        run_extra = {
          db: @options[:database],
          mode: (session_access_mode == :read ? 'r' : nil),
          tx_timeout: timeout_to_milliseconds(timeout),
          tx_metadata:
        }
        run_extra.reject! { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }

        connection = acquire_connection(session_access_mode)

        run_response =
          begin
            connection.send_message(Bolt::Message.run(query, parameters, run_extra))
            connection.send_message(Bolt::Message.pull)
            connection.flush
            connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException
            # Server is in FAILED state and any queued messages (e.g. the
            # PULL that followed our RUN) will be IGNORED. Drain them and
            # RESET so the connection is immediately reusable.
            connection.reset!
            @connection_provider.release(connection)
            raise
          rescue StandardError
            # Transport-level failure (IO/socket) — the connection is
            # likely dead. Return it to the pool either way so this lease
            # doesn't leak; the next user will rediscover the breakage.
            @connection_provider.release(connection)
            raise
          end

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)
        @current_result = Result.new(
          connection, keys,
          query_text: query, parameters: parameters, run_metadata: run_response.metadata,
          on_summary: method(:harvest_auto_commit_bookmark),
          on_release: -> { @connection_provider.release(connection) }
        )
      end

      def begin_transaction(timeout: nil, metadata: nil, &block)
        raise Exceptions::ClientException, 'Session is closed' unless @open
        if @transaction&.open?
          raise Exceptions::ClientException,
                "You cannot begin a transaction on a session with an open transaction; either run from within the transaction or use a different session."
        end

        drain_current_result
        @current_result = nil

        tx_options = @options.merge(
          timeout: timeout_to_milliseconds(timeout),
          metadata:
        ).compact

        @transaction = open_transaction(session_access_mode, tx_options)

        if block_given?
          begin
            result = yield @transaction
            # Explicit-block transactions default to rollback; user must call
            # tx.commit to persist changes (matches Java driver semantics).
            @transaction.rollback if @transaction.open?
            result
          rescue => e
            @transaction.rollback if @transaction.open?
            raise e
          ensure
            @transaction = nil
          end
        else
          @transaction
        end
      end

      def execute_read(timeout: nil, metadata: nil, &block)
        execute_transaction(AccessMode::READ, timeout:, metadata:, &block)
      end

      def execute_write(timeout: nil, metadata: nil, &block)
        execute_transaction(AccessMode::WRITE, timeout:, metadata:, &block)
      end

      # TODO(close-cancel-semantics): the buffer call below pulls every
      # remaining RECORD off the wire just to discard them client-side, and
      # any FAILURE that the drain surfaces gets silently swallowed by
      # Driver#session's block-form. Java-faithful behaviour is to send
      # DISCARD/RESET, abandon the stream server-side, and propagate
      # nothing — no swallow needed. Requires fixing Connection#reset! to
      # drain by terminal-for-RESET (not by queue-pop count). The
      # 'reports failure in close' integration spec encodes the current
      # incorrect contract and would need to flip. Tracked as backlog
      # item #12 in TESTKIT.md.
      def close
        return unless @open

        pending_error = nil
        begin
          @transaction&.close  # tx releases its own connection
          if @current_result
            connection = @current_result.connection
            begin
              @current_result.buffer
            rescue Exceptions::Neo4jException => e
              pending_error = e
            end
            # Any failure during the last result leaves the connection in
            # the server's FAILED state; RESET so the next borrower starts
            # from a clean READY state.
            connection.reset! if @current_result.failed?
            @current_result.discard!  # also releases the connection
          end
        ensure
          @open = false
        end

        raise pending_error if pending_error
      end

      def open?
        @open
      end

      def last_bookmarks
        @last_bookmarks
      end

      def update_bookmarks(bookmarks)
        # Replace bookmarks (don't accumulate) — matches Java driver behavior.
        # Each committed transaction generates a new bookmark that replaces the previous one.
        @last_bookmarks = Set.new(Array(bookmarks).map(&Bookmark.method(:new)))
      end

      private

      def acquire_connection(access_mode)
        @connection_provider.acquire(access_mode: access_mode, database: @options[:database])
      end

      # Default access mode for the session — drives connection routing for
      # auto-commit `run` calls. execute_read / execute_write override per
      # operation when going through `execute_transaction`.
      def session_access_mode
        case @options[:default_access_mode]
        when AccessMode::READ then :read
        else :write
        end
      end

      # Auto-commit hook called from Result when its stream ends in SUCCESS.
      # Explicit-tx Results don't trigger this — Transaction#commit harvests
      # the bookmark from the COMMIT response itself.
      def harvest_auto_commit_bookmark(summary)
        bookmark = summary.metadata[:bookmark]
        update_bookmarks(bookmark) if bookmark
      end

      # Pull any pending auto-commit result's records into memory so they
      # remain accessible from the user's reference after the connection is
      # released. The Result self-releases its connection on the SUCCESS
      # this drives. If draining surfaces a FAILURE we RESET the connection
      # before releasing so it goes back to the pool clean.
      def drain_current_result
        return unless @current_result

        # Detach first so any failure path doesn't leave @current_result
        # pointing at a connection we've already returned to the pool —
        # a later session.close would otherwise reset!/discard! a slot
        # that may already belong to another session.
        result = @current_result
        @current_result = nil
        connection = result.connection

        begin
          result.buffer
        rescue Exceptions::Neo4jException
          connection.reset!
          result.discard!  # idempotent; routes through Result#release_connection
          raise
        end

        if result.failed?
          connection.reset!
          result.discard!
        end
        # Successful drain: Result already released its connection from on_success.
      end

      # Convert timeout from seconds (or ActiveSupport::Duration) to milliseconds for Bolt protocol
      def timeout_to_milliseconds(timeout) = timeout&.then { (it.to_f * 1000).round }

      def execute_transaction(access_mode, timeout: nil, metadata: nil, &block)
        raise Exceptions::ClientException, 'Session is closed' unless @open

        # Drain any pending auto-commit result so its connection is released
        # and its bookmark is harvested before the managed tx acquires its
        # own connection (likely a different server in routing mode).
        drain_current_result

        max_retry_time = @options[:max_transaction_retry_time] || 2
        start_time = Time.now
        errors = []

        op_mode = (access_mode == AccessMode::READ ? :read : :write)
        tx_options = @options.merge(
          access_mode: access_mode == AccessMode::READ ? 'r' : 'w',
          timeout: timeout_to_milliseconds(timeout),
          metadata:
        ).compact

        loop do
          begin
            return run_managed_transaction(op_mode, tx_options, &block)
          rescue Exceptions::ServiceUnavailableException, Exceptions::TransientException => e
            errors << e

            if Time.now - start_time >= max_retry_time
              raise Exceptions::ServiceUnavailableException.new(
                "Transaction failed after retries: #{e.message}",
                code: e.code,
                suppressed: errors[0...-1]
              )
            end

            # Exponential backoff: 1s, 2s, 4s, ... matching Java driver defaults
            sleep(2 ** (errors.size - 1))
          end
        end
      end

      def run_managed_transaction(op_mode, tx_options, &block)
        if @transaction&.open?
          raise Exceptions::ClientException,
                "You cannot begin a transaction on a session with an open transaction"
        end

        @transaction = open_transaction(op_mode, tx_options)

        begin
          result = yield @transaction
          @transaction.commit if @transaction.open?
          result
        rescue => e
          @transaction.rollback if @transaction.open?
          raise e
        ensure
          @transaction = nil
        end
      end

      def open_transaction(op_mode, tx_options)
        connection = acquire_connection(op_mode)
        Transaction.new(connection, self, @last_bookmarks.to_a, tx_options,
                        on_release: -> { @connection_provider.release(connection) })
      end
    end
  end
end
