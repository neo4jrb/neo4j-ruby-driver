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
      def initialize(connection_provider, options = {}, clock: Internal::Clock.new)
        @connection_provider = connection_provider
        @options = options
        @clock = clock
        @transaction = nil
        @open = true
        @last_bookmarks = Set.new
        @current_result = nil
        # The home database this session pinned after its first resolution
        # (Optimization:HomeDatabaseCache); nil until then / for explicit-db sessions.
        @pinned_database = nil
        @used_guess = false  # whether an operation optimistically guessed the home db
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
        bookmarks = current_bookmarks_for_extra
        # Acquire (with its own bookmark snapshot) so the home-db cache can pick
        # the routing table: on a cache guess the RUN sends db=nil (server
        # re-resolves), otherwise it pins the discovered name. run_db carries
        # whichever applies; run_extra keeps this operation's bookmark snapshot.
        connection, run_db = acquire_for_operation(session_access_mode)
        run_extra = {
          db: run_db,
          mode: (session_access_mode == :read ? 'r' : nil),
          tx_timeout: timeout_to_milliseconds(timeout),
          tx_metadata:,
          imp_user: @options[:impersonated_user],
          bookmarks: bookmarks
        }
        run_extra.reject!(&Internal::Extras::BLANK)

        fetch_size = effective_fetch_size
        # Feature:IdempotentRetries — an auto-commit RUN whose failure the server
        # flags `_idempotent` may be retried once: RESET clears the FAILED state
        # (and drains the pipelined PULL's IGNORED), then RUN+PULL are re-sent
        # (TELEMETRY is not). Only the RUN reply is eligible — a telemetry failure
        # or a later stream (PULL) failure is raised as usual.
        retries_left = auto_commit_retries_enabled? ? 1 : 0

        buffer = handler = run_response = nil
        telemetry_sent = false    # TELEMETRY 2 = auto-commit; sent once, never resent on a retry
        telemetry_pending = false # its (opted-in) SUCCESS is still owed
        loop do
          # A fresh stream per attempt — a prior attempt's buffer saw the IGNORED.
          buffer = Bolt::RecordBuffer.new(fetch_size: fetch_size)
          handler = Bolt::StreamHandler.new(buffer)
          retry_run = false
          # `stage` tells the rescue which reply raised: only a :run failure is
          # idempotent-retryable (not :telemetry, nor a send/flush transport error).
          stage = nil
          run_response =
            begin
              # TELEMETRY is pipelined ahead of the first RUN when the server opted
              # in; kept inside this block so a send failure still releases the lease.
              unless telemetry_sent
                telemetry_sent = true
                telemetry_pending = connection.telemetry(2, disabled: @options[:telemetry_disabled])
              end
              # Auto-commit RUN carries this session's NotificationsConfig (5.2+);
              # the tx path puts it on BEGIN instead. nil / non-5.2 => absent.
              connection.send_message(connection.protocol.build_run(query, parameters, run_extra,
                                                                    notification_config: @options[:notification_config]))
              connection.send_message(connection.protocol.build_pull(n: fetch_size), handler)
              connection.flush
              if telemetry_pending
                telemetry_pending = false
                stage = :telemetry
                connection.fetch_response.assert_success!
              end
              stage = :run
              connection.fetch_response.assert_success!
            rescue Exceptions::Neo4jException => e
              # Classify first: this notifies the auth-token manager (and, for a
              # security failure, sets auth_failed so the guards below hold) and,
              # for routed connections, fires on_write_failure / deactivate and
              # swaps NotALeader for SessionExpired. assert_success! raises
              # *outside* RoutedConnection's wrapper, so this is the only place the
              # classifier sees FAILURE responses to RUN.
              classified = connection.classify_failure(e)
              if stage == :run && retries_left.positive? && idempotent_error?(e) && !connection.auth_failed
                retries_left -= 1
                # RESET clears FAILED and drains the abandoned RUN/PULL replies.
                connection.reset!
                retry_run = true
                nil
              else
                # Server is in FAILED state; RESET so the connection is immediately
                # reusable — but not if it's being discarded (auth failure: the
                # server closes it, RESET would just error).
                connection.reset! unless connection.auth_failed
                @connection_provider.release(connection)
                raise classified
              end
            rescue StandardError
              # Transport-level failure (IO/socket) — the connection is likely
              # dead. Return it to the pool either way so this lease doesn't leak;
              # the next user will rediscover the breakage.
              @connection_provider.release(connection)
              raise
            end
          break unless retry_run
        end

        # A home-db RUN that sent db=nil comes back with the server's resolved
        # home database — cache it so the next same-identity session can guess.
        cache_home_db_from(run_response)

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)
        @current_result = Result.new(
          connection, keys, buffer: buffer, handler: handler,
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
          # The resolved home database is added in open_transaction, where the
          # BEGIN bookmark snapshot is computed (so resolution and BEGIN share
          # one snapshot).
          timeout: timeout_to_milliseconds(timeout),
          metadata:,
          # BEGIN carries `mode: "r"` for read sessions (write is the
          # server default and omits it), matching the auto-commit path.
          # The Transaction reads tx_options[:access_mode]; without this an
          # explicit read transaction dropped the field (session stores the
          # mode under :default_access_mode, not :access_mode).
          access_mode: (session_access_mode == :read ? 'r' : nil)
        ).compact

        # TELEMETRY 1 = unmanaged (explicit) transaction.
        @transaction = open_transaction(session_access_mode, tx_options, telemetry_api: 1)

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

      # The database name to put on the wire for this session's operations.
      # An explicit `:database` is used as-is. For a home-db session (nil) on
      # a routing driver, resolve the name from discovery once and reuse it
      # (Bolt 4.4+/5.x return it in the ROUTE reply); the direct provider and
      # the procedure-based protocols return nil, leaving the server to
      # resolve the home db from an absent `db`.
      # `bookmarks` is the snapshot the caller is already using for this
      # operation's wire `bookmarks` — passed in (not recomputed) so a single
      # operation never takes two different BookmarkManager snapshots.
      # Acquire the operation's connection and decide the db it should send
      # (Optimization:HomeDatabaseCache). Returns [connection, run_db]:
      #   - explicit :database  -> acquire against it, send it.
      #   - home-db + cache guess (SSR pool) -> acquire against the guessed home
      #     db (reuses its routing table, no discovery) but send db=nil so the
      #     server re-resolves; unless the acquired connection turns out non-SSR
      #     (a mixed cluster can't re-route), in which case fall back to explicit
      #     discovery and pin the resolved name.
      #   - home-db, no guess -> discover, pin, send the resolved name.
      def acquire_for_operation(access_mode)
        # Its own bookmark snapshot for discovery/acquire — distinct from the
        # RUN/BEGIN extra's snapshot, so a BookmarkManager supplier is consulted
        # once per acquire (matching the reference drivers / the bookmark-manager
        # tests), and home-db discovery routes with a fresh set.
        bookmarks = current_bookmarks_for_extra
        explicit = @options[:database]
        return [do_acquire(access_mode, explicit, bookmarks), explicit] if explicit
        # Once this session has resolved its home db, pin it for the rest of the
        # session — later runs send it explicitly so a re-resolving server can't
        # move the session to a different database mid-flight.
        return [do_acquire(access_mode, @pinned_database, bookmarks), @pinned_database] if @pinned_database

        imp_user = @options[:impersonated_user]
        auth = @options[:auth_token]
        # Guess only pays off when we already hold a fresh routing table for it:
        # acquire against that table and send db=nil so the server resolves the
        # real home db. If its table is stale (or the connection turns out
        # non-SSR), fall through to explicit discovery — a ROUTE with db=nil that
        # authoritatively resolves and pins the home db. The optimistic acquire
        # and the fallback share one acquisition-timeout deadline.
        guess = @connection_provider.home_db_guess(imp_user, auth)
        if guess && @connection_provider.routing_table_fresh?(guess, access_mode)
          deadline = acquisition_deadline
          connection = do_acquire(access_mode, guess, bookmarks, deadline)
          if connection.ssr_enabled?
            # A real guess: the reply's db will pin the session (cache_home_db_from).
            @used_guess = true
            return [connection, nil]
          end

          @connection_provider.release(connection)
          resolved = @connection_provider.home_database(bookmarks, imp_user, auth)
          @pinned_database = resolved
          return [do_acquire(access_mode, resolved, bookmarks, deadline), resolved]
        end
        resolved = @connection_provider.home_database(bookmarks, imp_user, auth)
        @pinned_database = resolved
        [do_acquire(access_mode, resolved, bookmarks), resolved]
      end

      def do_acquire(access_mode, database, bookmarks, deadline = nil)
        @connection_provider.acquire(access_mode: access_mode, database: database, bookmarks: bookmarks,
                                     imp_user: @options[:impersonated_user], auth: @options[:auth_token],
                                     deadline: deadline)
      end

      # A single acquisition-timeout deadline (monotonic seconds) so a guessed
      # acquire and its fallback share one budget, matching the reference drivers.
      def acquisition_deadline
        @clock.monotonic + (@options[:connection_acquisition_timeout]&.to_f || 60)
      end

      # Record the server's resolved home database from a RUN/BEGIN reply, so a
      # later same-identity session guesses it. No-op for explicit-db sessions
      # (their reply omits db) and the direct provider (cache_home_db is a no-op).
      def cache_home_db_from(response)
        db = response.metadata[:db]
        return if db.nil? || @options[:database]

        # First guess-based run learns the real home db from the reply — pin it
        # for the session (only when we actually guessed; direct drivers never
        # pin) and remember it for the driver-wide cache.
        @pinned_database ||= db if @used_guess
        @connection_provider.cache_home_db(@options[:impersonated_user], @options[:auth_token], db)
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

      # Feature:IdempotentRetries. A session-level AutoCommitRetriesMode wins;
      # otherwise fall back to the driver-level `auto_commit_retries_disabled`
      # default (merged into the session options), which defaults to enabled.
      def auto_commit_retries_enabled?
        case @options[:auto_commit_retries_mode]
        when AutoCommitRetriesMode::ENABLED then true
        when AutoCommitRetriesMode::DISABLED then false
        else !@options[:auto_commit_retries_disabled]
        end
      end

      # A server FAILURE the server marks retryable via `_idempotent` in its
      # diagnostic record.
      def idempotent_error?(error)
        error.diagnostic_record&.[](:_idempotent) == true
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

        # Default matches Java's Config.DEFAULT_MAX_TRANSACTION_RETRY_TIME
        # (30s). The window matters for cluster failover: a leader election
        # can take several seconds, during which the router keeps returning
        # the old/no leader, so the managed-tx retry must keep rediscovering
        # (with exponential backoff) well past a second or two.
        max_retry_time = @options[:max_transaction_retry_time] || 30
        start_time = @clock.realtime
        errors = []
        # TELEMETRY 0 (managed tx) is reported until the server acknowledges it:
        # re-sent on each attempt whose telemetry never landed (e.g. the
        # connection died before its SUCCESS), but not once acked — matching the
        # reference drivers and the retry stub script. The callback flips this
        # the moment a Transaction reads the telemetry SUCCESS.
        telemetry_acked = false
        on_telemetry_ack = -> { telemetry_acked = true }

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
            # api 0 = managed tx; execute_query's session overrides it to 3
            # (DRIVER_EXECUTE_QUERY). nil once the server has acked the report.
            telemetry_api = telemetry_acked ? nil : (@options[:telemetry_api] || 0)
            return run_managed_transaction(op_mode, tx_options, telemetry_api, on_telemetry_ack, &block)
          rescue Exceptions::ServiceUnavailableException, Exceptions::SessionExpiredException,
                 Exceptions::TransientException,
                 # AuthorizationExpired (server authz-cache expiry) is always
                 # retryable; SecurityRetryableException is an auth failure the
                 # token manager has flagged retryable (token refreshed) — both
                 # warrant another attempt on a fresh connection/identity.
                 Exceptions::AuthorizationExpiredException, Exceptions::SecurityRetryableException => e
            errors << e

            if @clock.realtime - start_time >= max_retry_time
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

      def run_managed_transaction(op_mode, tx_options, telemetry_api, on_telemetry_ack, &block)
        if @transaction&.open?
          raise Exceptions::ClientException,
                "You cannot begin a transaction on a session with an open transaction"
        end

        # TELEMETRY 0 = managed transaction function; api is nil once acked so a
        # retry doesn't repeat it.
        @transaction = open_transaction(op_mode, tx_options, telemetry_api: telemetry_api,
                                        telemetry_ack: on_telemetry_ack)

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

      def open_transaction(op_mode, tx_options, telemetry_api:, telemetry_ack: nil)
        # Acquire and decide the BEGIN db together (Optimization:HomeDatabaseCache):
        # a cache guess picks the routing table and sends db=nil; otherwise the
        # discovered/pinned name is sent. It takes its own bookmark snapshot for
        # discovery. begin_db is dropped when nil via compact.
        connection, begin_db = acquire_for_operation(op_mode)
        # The BEGIN's own snapshot, taken last so current_bookmarks_for_extra
        # records @bookmarks_used_on_begin as the set actually sent on BEGIN (the
        # commit-time update_bookmarks reports it as `previous`).
        bookmarks = current_bookmarks_for_extra
        tx_options = tx_options.merge(database: begin_db).compact
        Transaction.new(connection, self, bookmarks, tx_options, telemetry_api: telemetry_api,
                        telemetry_ack: telemetry_ack,
                        # executeQuery's session reports telemetry api 3 (DRIVER_EXECUTE_QUERY);
                        # only that path pipelines BEGIN + RUN + PULL (Optimization:ExecuteQueryPipelining).
                        pipelined: @options[:telemetry_api] == 3,
                        on_begin: method(:cache_home_db_from),
                        on_release: -> { @connection_provider.release(connection) })
      end
    end
  end
end
