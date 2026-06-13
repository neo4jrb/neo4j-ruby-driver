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
      include Internal::DurationNormalizer
      def initialize(connection_provider, options = {})
        @connection_provider = connection_provider
        @options = options
        @transaction = nil
        @open = true
        @last_bookmarks = Set.new
        @current_result = nil
        @bookmark_manager = options[:bookmark_manager]
        # The bookmark snapshot we sent on the most recent BEGIN — used
        # as `previous_bookmarks` when forwarding to the manager so it
        # set-difference-drops what it knew before. Computed at BEGIN
        # time (not update time) because the manager may have grown
        # between the two via another session.
        @bookmarks_used_on_begin = nil

        # Initialize with provided bookmarks if any
        if options[:bookmarks]
          initial_bookmarks = options[:bookmarks]
          initial_bookmarks = [initial_bookmarks] unless initial_bookmarks.is_a?(Enumerable)
          initial_bookmarks.each do |bookmark|
            @last_bookmarks << (bookmark.is_a?(Bookmark) ? bookmark : Bookmark.from(bookmark))
          end
        end
      end

      def run(query, parameters = {}, config = {})
        Internal::Validator.require_query_text!(query)
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
        # `bookmarks` is the current bookmark snapshot so server-side
        # causal consistency works across auto-commit runs without an
        # explicit transaction.
        # `imp_user` (Bolt 4.4+) makes the server run the query as if
        # the named user had issued it — auth as the session's user,
        # authz as the impersonated one.
        run_extra = {
          db: @options[:database],
          mode: (session_access_mode == :read ? 'r' : nil),
          tx_timeout: timeout_to_milliseconds(timeout),
          tx_metadata:,
          imp_user: @options[:impersonated_user],
          bookmarks: current_bookmarks_for_extra
        }
        run_extra.reject!(&Internal::Extras::BLANK)

        connection = acquire_connection(session_access_mode)
        fetch_size = effective_fetch_size

        run_response =
          begin
            connection.send_message(connection.protocol.build_run(query, parameters, run_extra))
            connection.send_message(connection.protocol.build_pull(n: fetch_size))
            connection.flush
            connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException => e
            # Classify first: this notifies the auth-token manager (and
            # may flag the connection for discard on an auth failure) and,
            # for routed connections, fires on_write_failure / deactivate
            # and swaps NotALeader for SessionExpired. assert_success!
            # raises *outside* RoutedConnection's wrapper, so this is the
            # only place the classifier sees FAILURE responses to RUN.
            classified = connection.classify_failure(e)
            # Server is in FAILED state; RESET so the connection is
            # immediately reusable — but not if it's being discarded
            # (auth failure: the server closes it, RESET would just error).
            connection.reset! unless connection.auth_failed
            @connection_provider.release(connection)
            raise classified
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
          fetch_size: fetch_size,
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
          metadata:,
          # BEGIN carries `mode: "r"` for read sessions (write is the
          # server default and omits it), matching the auto-commit path.
          # The Transaction reads tx_options[:access_mode]; without this an
          # explicit read transaction dropped the field (session stores the
          # mode under :default_access_mode, not :access_mode).
          access_mode: (session_access_mode == :read ? 'r' : nil)
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

      # Close any pending result by asking the server to abandon
      # remaining records (DISCARD) rather than pulling them just to
      # throw them away client-side. Matches Java's behaviour and is
      # required by testkit's session_run.test_discard_on_session_close_*
      # scripts which lie about has_more=true to verify the driver
      # eventually sends DISCARD. With pagination, draining via buffer
      # would loop forever on those scripts.
      def close
        return unless @open

        pending_error = nil
        begin
          @transaction&.close  # tx releases its own connection
          if @current_result
            connection = @current_result.connection
            begin
              @current_result.consume
            rescue Exceptions::Neo4jException => e
              pending_error = e
            end
            # Any failure during the consume leaves the connection in
            # the server's FAILED state; RESET so the next borrower starts
            # from a clean READY state.
            connection.reset! if @current_result.failed?
            @current_result.discard!  # idempotent; releases the connection
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
        new_set = Set.new(Array(bookmarks).map(&Bookmark.method(:from)))
        # Forward to the BookmarkManager (if configured) so cross-session
        # causal consistency works. Pass the bookmarks we *sent* in BEGIN
        # as `previous` — Java's manager uses set-difference, so passing
        # the session's own bookmarks alongside the manager's is safe.
        @bookmark_manager&.update_bookmarks(@bookmarks_used_on_begin || @last_bookmarks, new_set)
        @last_bookmarks = new_set
      end

      private

      def acquire_connection(access_mode)
        connection = @connection_provider.acquire(
          access_mode: access_mode,
          database: @options[:database],
          bookmarks: current_bookmarks_for_extra,
          # Threaded into routing discovery so the ROUTE call enforces
          # impersonation support (Bolt 4.4+) before sending; the direct
          # provider ignores it (RUN/BEGIN enforce it instead).
          imp_user: @options[:impersonated_user]
        )
        # Ensure the pooled connection holds the right identity.
        #
        # A non-nil per-session `:auth_token` pins this session to that
        # identity (matches Java's SessionConfig.withAuthToken so the JRuby
        # ConfigConverter delegates via with_auth_token without special-
        # casing) and always re-auths — correctly erroring on Bolt < 5.1,
        # where per-session auth is unsupported.
        #
        # With no per-session token, the default identity is the auth-token
        # manager's current token (refreshed/rotated as needed). It's
        # applied via in-place re-auth only where re-auth exists (Bolt
        # 5.1+); on 5.0 a pooled connection keeps its creation-time token
        # and the manager's refresh reaches new connections instead (an
        # in-place re-auth would wrongly raise on a still-valid token).
        # authenticate is a no-op when the target identity already matches.
        if @options[:auth_token]
          connection.authenticate(@options[:auth_token])
        elsif connection.protocol.supports_re_auth?
          connection.authenticate(@connection_provider.current_auth_token)
        end
        connection
      end


      # Current bookmark snapshot as a plain array of strings, ready
      # for the wire. Returns nil when empty so the BEGIN/RUN extras
      # hash's `reject!` strips the key entirely (testkit's stub
      # scripts strictly compare against omission).
      #
      # Folds in the BookmarkManager's bookmarks too (when configured)
      # so cross-session causal consistency works. Records the merged
      # set on @bookmarks_used_on_begin so update_bookmarks can pass
      # it as `previous` to the manager. A custom manager can return
      # plain strings rather than Bookmark instances, so coerce
      # everything via Bookmark.from before reading .value.
      def current_bookmarks_for_extra
        from_manager = Array(@bookmark_manager&.bookmarks).map(&Bookmark.method(:from))
        merged = @last_bookmarks | from_manager
        @bookmarks_used_on_begin = merged
        bookmarks = merged.to_a.map(&:value)
        bookmarks unless bookmarks.empty?
      end

      # Records per PULL batch. Matches Java/Python defaults (1000). The
      # user can override per-driver via the `fetch_size` option and the
      # special value `-1` means "pull all records in one batch".
      def effective_fetch_size
        size = @options[:fetch_size]
        size.nil? ? 1000 : size
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
        # `metadata` is private on ResultSummary (deliberately not part of
        # the public Java-shaped API). Bookmark only ever lives on the wire
        # SUCCESS metadata; no public Summary accessor for it because Java's
        # ResultSummary doesn't expose one either. send() bypasses the
        # private check for this internal-only consumer.
        bookmark = summary.send(:metadata)[:bookmark]
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
          # BEGIN carries `mode: "r"` for read; write is the server default
          # and omits the field (reference drivers and the stub scripts
          # expect `BEGIN {"db": ...}`, not `…"mode": "w"`). Matches the
          # auto-commit and explicit-begin paths; `compact` drops the nil.
          access_mode: (access_mode == AccessMode::READ ? 'r' : nil),
          timeout: timeout_to_milliseconds(timeout),
          metadata:
        ).compact

        loop do
          begin
            return run_managed_transaction(op_mode, tx_options, &block)
          rescue Exceptions::ServiceUnavailableException, Exceptions::SessionExpiredException,
                 Exceptions::TransientException => e
            errors << e

            if Time.now - start_time >= max_retry_time
              # Retries exhausted — re-raise the LAST error with its real
              # type (SessionExpired / Transient / ServiceUnavailable)
              # rather than flattening everything to ServiceUnavailable;
              # Java's transaction executor likewise rethrows the last
              # error. testkit asserts on the type (e.g. a routed reader
              # interruption must surface as SessionExpired), so the
              # generic wrapper masked it. Earlier attempts ride along as
              # suppressed.
              e.add_suppressed(*errors[0...-1])
              raise e
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
