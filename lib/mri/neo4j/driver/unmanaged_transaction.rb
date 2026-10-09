# frozen_string_literal: true

module Neo4j
  module Driver
    # An explicit (unmanaged) transaction: the full lifecycle — run, commit,
    # rollback, close. This is what session.begin_transaction yields/returns.
    # Managed functions (execute_read/execute_write) instead yield a
    # Transaction, a thin context that exposes only #run and delegates to an
    # UnmanagedTransaction the driver owns.
    #
    # rubocop:disable Metrics/ClassLength -- the full explicit-transaction
    # lifecycle (begin/run/commit/rollback/close plus failure recovery) is one
    # cohesive unit over shared state (@open/@failed/@open_results); extracting
    # helpers only makes the class longer, and splitting it across collaborators
    # would scatter that state for no real gain.
    class UnmanagedTransaction
      attr_reader :connection

      # rubocop:disable Metrics/ParameterLists -- a constructor wiring the
      # transaction's real collaborators (connection, session) plus its
      # pipelining / telemetry / lifecycle hooks; a params object would only
      # relocate the list, not shorten what has to be supplied.
      def initialize(connection, session, bookmarks = [], options = {}, telemetry_api: nil, telemetry_ack: nil,
                     pipelined: false, on_begin: nil, on_release: nil)
        @connection = connection
        @session = session
        @options = options
        # executeQuery pipelines BEGIN + RUN + PULL (Optimization:ExecuteQueryPipelining):
        # BEGIN's reply is read only after the first RUN+PULL are flushed, not eagerly.
        @pipelined = pipelined
        @on_begin = on_begin # called with the BEGIN reply (home-db cache update)
        @on_release = on_release # called once when the connection is no longer needed
        @telemetry_ack = telemetry_ack
        reset_state!
        begin_transaction!(bookmarks, telemetry_api)
      end
      # rubocop:enable Metrics/ParameterLists

      def run(query, **parameters)
        assert_runnable!(query)

        # A new query becomes current; the previous result must now name its qid
        # explicitly on further PULL/DISCARD (the server defaults them to the last
        # opened query). We keep it open and streaming rather than buffering it —
        # that's the qid multiplexing the nested-result tests exercise.
        @current_result&.demote!

        @current_result = execute_run(query, parameters)
        @open_results << @current_result
        @current_result
      end

      def commit
        assert_committable!
        return abort_terminated_commit! if terminated?

        drain_results_before_commit!
        finalize_commit(send_commit!)
      end

      def rollback
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open

        # A pipelined executeQuery tx whose query never ran (e.g. local validation
        # failed before RUN/PULL were sent) left BEGIN's reply unread — and a
        # pipelining server may withhold it until RUN/PULL arrive, which now never
        # will. RESET rolls the tx back and drains any pending reply without a
        # blocking read that could deadlock; there are no open results to discard.
        return rollback_via_reset unless @begin_acked

        # A terminated tx left the connection FAILED: don't drain open results
        # (that would send PULL/DISCARD the server rejects) — just RESET.
        return rollback_via_reset if terminated?

        drain_results_quietly
        return rollback_via_reset if @failed

        send_rollback!
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

      # Initial lifecycle flags for a fresh tx: open, un-committed,
      # un-rolled-back, un-failed, no current result, no terminating error.
      def reset_state!
        @open = true
        @committed = false
        @rolled_back = false
        @failed = false
        @terminating_error = nil # the classified error that terminated this tx (a RUN/commit failure)
        @current_result = nil
        # Every result opened in this tx, in order. Bolt lets multiple stay open
        # and streaming concurrently (qid multiplexing); a new RUN no longer
        # force-buffers the previous one, so we track them all here to discard
        # any still-open at commit/rollback and to spot a mid-stream failure.
        @open_results = []
        @begin_acked = false
      end

      # Open the transaction on the wire: TELEMETRY (api = 0 managed / 1 explicit
      # / 3 executeQuery) pipelined ahead of BEGIN when the server opted in and
      # the driver didn't disable it, then BEGIN itself. Non-pipelined reads
      # BEGIN's reply now (a plain round-trip); pipelined (executeQuery) defers it
      # so the first #run can flush RUN+PULL before we block — #ack_begin! drains
      # it after that flush.
      def begin_transaction!(bookmarks, telemetry_api)
        begin_extra = build_begin_extra(bookmarks)
        @telemetry_sent = @connection.telemetry(telemetry_api, disabled: @options[:telemetry_disabled])
        # Session-level NotificationsConfig rides on BEGIN (5.2+); the tx's own
        # RUNs carry none. nil / pre-5.2 => no notification keys on the wire.
        @connection.send_message(@connection.protocol.build_begin(begin_extra,
                                                                  notification_config: @options[:notification_config]))
        @connection.flush
        ack_begin! unless @pipelined
      rescue Exceptions::Neo4jException => e
        fail_begin_classified(e)
      rescue StandardError
        fail_begin_transport
      end

      # The BEGIN extra map with blank values dropped, so the serialised map
      # matches what testkit's stub scripts expect (e.g. `BEGIN {"db": "adb"}`,
      # not `BEGIN {"db": "adb", "tx_metadata": {}}`).
      def build_begin_extra(bookmarks)
        {
          bookmarks: bookmarks,
          db: @options[:database],
          mode: @options[:access_mode],
          tx_timeout: @options[:timeout],
          tx_metadata: @options[:metadata],
          imp_user: @options[:impersonated_user]
        }.reject(&Internal::Extras::BLANK)
      end

      # BEGIN failed with a server error: classify first so the auth-token
      # manager is notified and the connection is flagged for discard on an auth
      # failure (the server closes it), then RESET to make it reusable — unless
      # it's being discarded (a security failure: RESET would just error).
      def fail_begin_classified(error)
        classified = @connection.classify_failure(error)
        @connection.reset! unless @connection.auth_failed
        @open = false
        release_connection
        raise classified
      end

      # BEGIN failed at the transport level (IO/socket). RESET would likely fail
      # on a dead connection too; just release the lease so it doesn't leak, and
      # let pool reuse surface the breakage to the next caller.
      def fail_begin_transport
        @open = false
        release_connection
        raise
      end

      # Reject further work locally (no wire traffic) when the tx has terminated
      # or closed, with Java/JRuby-aligned messages so both impls report the same
      # reason. A terminated tx raises TransactionTerminatedException (a
      # ClientException subclass, matching Java); the wording stays "rolled back"
      # (a shared spec asserts it on both impls) while the class becomes specific.
      def assert_runnable!(query)
        Internal::Validator.require_query_text!(query)
        if terminated?
          raise Exceptions::TransactionTerminatedException,
                'Cannot run more queries in this transaction, it has been rolled back'
        end
        return if @open

        raise Exceptions::ClientException,
              "Cannot run more queries in this transaction, it has been #{@committed ? 'committed' : 'rolled back'}"
      end

      # Send RUN+PULL, drain the (possibly pipelined) BEGIN reply, and build the
      # streaming Result that becomes current.
      def execute_run(query, parameters)
        fetch_size = effective_fetch_size
        buffer = Bolt::RecordBuffer.new(fetch_size: fetch_size)
        handler = Bolt::StreamHandler.new(buffer)
        run_response = send_run(query, parameters, handler, fetch_size)
        Result.new(@connection, result_keys(run_response), buffer: buffer, handler: handler,
                                                           query_text: query, parameters: parameters,
                                                           run_metadata: run_response.metadata, fetch_size: fetch_size,
                                                           qid: run_response.metadata[:qid],
                                                           terminated_error: method(:terminating_error))
      end

      # RUN+PULL on the wire, then the RUN response. send/flush are here (not in
      # #execute_run) so a transport-level failure still sets @failed and goes
      # through classify_failure. Connection#send_message and #flush both defer
      # peer-closed errors so a buffered server FAILURE is read before
      # fetch_response raises its own EOF-driven ServiceUnavailableException —
      # JRuby surfaces EPIPE eagerly, MRI tends to defer it. On failure we record
      # the terminating error: sibling results still open must raise it (not pull)
      # once this RUN fails — the connection is FAILED.
      def send_run(query, parameters, handler, fetch_size)
        @connection.send_message(@connection.protocol.build_run(query, parameters, {}))
        @connection.send_message(@connection.protocol.build_pull(n: fetch_size), handler)
        @connection.flush
        # Drain the pipelined BEGIN (+telemetry) reply now that RUN+PULL are on
        # the wire — no-op unless this is the pipelined first run. A BEGIN that
        # failed surfaces here and is handled as a run failure; the tx then rolls
        # back on its way out, resetting the connection.
        ack_begin!
        @connection.fetch_response.assert_success!
      rescue Exceptions::Neo4jException => e
        @failed = true
        raise(@terminating_error = @connection.classify_failure(e))
      end

      def result_keys(run_response)
        (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)
      end

      # Guard the already-closed states before COMMIT, Java/JRuby-aligned.
      def assert_committable!
        raise Exceptions::ClientException, 'Can\'t commit, transaction has been committed' if @committed
        raise Exceptions::ClientException, 'Can\'t commit, transaction has been rolled back' if @rolled_back
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open
      end

      # A terminated tx can't commit: RESET it and report the rollback.
      def abort_terminated_commit!
        rollback_via_reset
        raise Exceptions::TransactionTerminatedException,
              "Transaction can't be committed. It has been rolled back"
      end

      # Discard still-open results before COMMIT; a failure here rolls the tx back
      # via RESET and re-raises.
      def drain_results_before_commit!
        discard_open_results
      rescue Exceptions::Neo4jException
        rollback_via_reset
        raise
      end

      # COMMIT on the wire. send/flush inside this method — see #send_run for the
      # JRuby-vs-MRI socket-write timing rationale. On failure, classify first (so
      # a security failure flags the connection for discard before
      # rollback_via_reset releases it), then RESET and re-raise.
      def send_commit!
        @connection.send_message(Bolt::Message.commit)
        @connection.flush
        @connection.fetch_response.assert_success!
      rescue Exceptions::Neo4jException => e
        @failed = true
        classified = @connection.classify_failure(e)
        rollback_via_reset
        raise classified
      end

      # A clean COMMIT: mark closed, adopt the returned bookmark, release.
      def finalize_commit(response)
        @committed = true
        @open = false
        bookmarks = response.metadata[:bookmark]
        @session.update_bookmarks(bookmarks) if bookmarks
        release_connection
      end

      # Discard still-open results during ROLLBACK, swallowing failures: the tx is
      # being discarded anyway, discard_open_results has set @failed, and the
      # RESET path below cleans up the connection.
      def drain_results_quietly
        discard_open_results
      rescue Exceptions::Neo4jException
        nil
      end

      # ROLLBACK on the wire. A broken/dead connection makes this a no-op (the
      # server discards the tx when the link dies) — swallow ServiceUnavailable /
      # SessionExpired so session.close's rollback path stays clean. A server
      # FAILURE on ROLLBACK (e.g. DatabaseUnavailable) is real: the connection is
      # now FAILED, so RESET it back to READY then surface through the routing
      # classifier (so routing side effects like deactivate fire and the type is
      # consistent; no-op for direct connections). Either way, finalise as
      # rolled-back and release.
      def send_rollback!
        @connection.send_message(Bolt::Message.rollback)
        @connection.flush
        @connection.fetch_response.assert_success!
      rescue Exceptions::ServiceUnavailableException, Exceptions::SessionExpiredException
        nil
      rescue Exceptions::Neo4jException => e
        @connection.reset!
        raise @connection.classify_failure(e)
      ensure
        mark_rolled_back
      end

      # Read the deferred BEGIN acknowledgement (and the telemetry SUCCESS
      # pipelined ahead of it). Idempotent: called once — eagerly in #initialize
      # for a normal tx, or after the first RUN+PULL flush for a pipelined
      # executeQuery (and defensively before ROLLBACK if that query never ran).
      def ack_begin!
        return if @begin_acked

        @begin_acked = true

        if @telemetry_sent
          @connection.fetch_response.assert_success!
          # The server acknowledged telemetry; a managed-tx retry won't re-send it.
          @telemetry_ack&.call
        end
        begin_response = @connection.fetch_response.assert_success!
        # A home-db BEGIN that sent db=nil comes back with the resolved name.
        @on_begin&.call(begin_response)
        begin_response
      end

      # The transaction is terminated once a server failure has hit it — either
      # a tx method caught it (@failed) or any open result failed during the
      # user's own iteration (its failure hasn't passed through a tx method).
      def terminated? = @failed || @open_results.any?(&:failed?)

      # The error that terminated this tx, or nil. A RUN/commit failure records
      # it directly; a result that failed mid-iteration (the user's own PULL)
      # carries it on the result. Passed to each result as its terminated_error
      # so a sibling raises it instead of pulling on a FAILED connection.
      def terminating_error = @terminating_error || @open_results.find(&:failed?)&.failure

      # See Session#effective_fetch_size. Transactions inherit the session
      # options at open, so the same default rules apply.
      def effective_fetch_size
        size = @options[:fetch_size]
        size.nil? ? 1000 : size
      end

      # At tx end (commit/rollback) every still-open result goes out of scope,
      # so discard each — DISCARD abandons remaining records (essential when a
      # result is unbounded) rather than streaming them into memory, and leaves
      # each raising ResultConsumedException on later access. Demoted results
      # DISCARD by their qid; the current one omits it (targets the last query).
      def discard_open_results
        @open_results.each { |result| discard_result(result) }
      end

      def discard_result(result)
        result.consume
        # consume is a no-op when the result was already drained by the user;
        # surface any stored failure so callers can react.
        @failed = true if result.failed?
      rescue Exceptions::Neo4jException => e
        @failed = true
        # A wire error during PULL streaming (e.g. a reader connection
        # interrupted mid-stream) raises ServiceUnavailable straight from
        # fetch_response, not via Result#on_failure — so it never saw the
        # routing classifier. Run it through here so a routed connection
        # failure surfaces as SessionExpired (idempotent if already classified).
        raise @connection.classify_failure(e)
      end

      # Recover a failed transaction by asking the server to RESET the
      # connection. RESET transitions the server from FAILED back to READY
      # and implicitly rolls back the open transaction.
      def rollback_via_reset
        # Skip RESET on a connection being discarded (auth failure: the
        # server closes it, RESET would just error); release then honors
        # the discard flag so it isn't pooled.
        @connection.reset! unless @connection.auth_failed
        mark_rolled_back
      end

      # Finalise the transaction as rolled back and release its connection —
      # the shared tail of both rollback paths (RESET recovery and a plain
      # ROLLBACK's ensure).
      def mark_rolled_back
        @rolled_back = true
        @open = false
        release_connection
      end

      def release_connection
        @on_release&.call
        @on_release = nil # idempotent
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
