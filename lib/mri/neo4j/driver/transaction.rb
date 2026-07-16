# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents an explicit transaction
    class Transaction
      attr_reader :connection

      def initialize(connection, session, bookmarks = [], options = {}, telemetry_api: nil, telemetry_ack: nil,
                     pipelined: false, on_release: nil)
        @connection = connection
        @session = session
        @options = options
        # executeQuery pipelines BEGIN + RUN + PULL (Optimization:ExecuteQueryPipelining):
        # BEGIN's reply is read only after the first RUN+PULL are flushed, not eagerly.
        @pipelined = pipelined
        @on_release = on_release  # called once when the connection is no longer needed
        @open = true
        @committed = false
        @rolled_back = false
        @failed = false
        @terminating_error = nil  # the classified error that terminated this tx (a RUN/commit failure)
        @current_result = nil
        # Every result opened in this tx, in order. Bolt lets multiple stay open
        # and streaming concurrently (qid multiplexing); a new RUN no longer
        # force-buffers the previous one, so we track them all here to discard
        # any still-open at commit/rollback and to spot a mid-stream failure.
        @open_results = []

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

        # TELEMETRY (api = 0 managed / 1 explicit / 3 executeQuery) pipelined
        # ahead of BEGIN when the server opted in and the driver didn't disable
        # it; its SUCCESS is read first (see #ack_begin!).
        @telemetry_sent = @connection.telemetry(telemetry_api, disabled: options[:telemetry_disabled])
        @telemetry_ack = telemetry_ack
        # Session-level NotificationsConfig rides on BEGIN (5.2+); the tx's own
        # RUNs carry none. nil / pre-5.2 => no notification keys on the wire.
        @connection.send_message(@connection.protocol.build_begin(begin_extra,
                                                                  notification_config: options[:notification_config]))
        @connection.flush

        # Non-pipelined: read BEGIN's reply now, a plain round-trip (unchanged).
        # Pipelined (executeQuery): defer it so the first #run can flush RUN+PULL
        # before we block — a pipelining server withholds BEGIN's SUCCESS until it
        # has all three. #ack_begin! drains it after that flush.
        @begin_acked = false
        ack_begin! unless @pipelined
      rescue Exceptions::Neo4jException => e
        # Classify first so the auth-token manager is notified and the
        # connection is flagged for discard on an auth failure (the server
        # closes it). BEGIN failed → server is in FAILED state; RESET to
        # make it reusable, unless it's being discarded (a security
        # failure: the server closes it and RESET would just error).
        classified = @connection.classify_failure(e)
        @connection.reset! unless @connection.auth_failed
        @open = false
        release_connection
        raise classified
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
        # A server failure terminated this transaction; further work is
        # rejected locally (no wire traffic) as a TransactionTerminatedException
        # — a ClientException subclass, matching the Java driver. Covers both a
        # failed RUN (sets @failed) and a result that failed mid-stream during
        # the user's own iteration (@current_result.failed?). Message wording
        # stays "rolled back" to match the Java flavor (a shared integration spec
        # asserts it on both impls); only the exception class becomes specific.
        raise Exceptions::TransactionTerminatedException,
              'Cannot run more queries in this transaction, it has been rolled back' if terminated?
        unless @open
          # Mirror the Java/JRuby messages so the closed-state reason
          # (committed vs rolled back) is reported the same on both impls.
          raise Exceptions::ClientException,
                "Cannot run more queries in this transaction, it has been #{@committed ? 'committed' : 'rolled back'}"
        end

        # A new query becomes current; the previous result must now name its qid
        # explicitly on further PULL/DISCARD (the server defaults them to the last
        # opened query). We keep it open and streaming rather than buffering it —
        # that's the qid multiplexing the nested-result tests exercise.
        @current_result&.demote!

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
        buffer = Bolt::RecordBuffer.new(fetch_size: fetch_size)
        handler = Bolt::StreamHandler.new(buffer)
        run_response =
          begin
            @connection.send_message(@connection.protocol.build_run(query, parameters, {}))
            @connection.send_message(@connection.protocol.build_pull(n: fetch_size), handler)
            @connection.flush
            # Drain the pipelined BEGIN (+telemetry) reply now that RUN+PULL are on
            # the wire — no-op unless this is the pipelined first run. A BEGIN that
            # failed surfaces here and is handled as a run failure below; the tx
            # then rolls back on its way out, resetting the connection.
            ack_begin!
            @connection.fetch_response.assert_success!
          rescue Exceptions::Neo4jException => e
            @failed = true
            # Remember the terminating error: sibling results still open must
            # raise it (not pull) once this RUN fails — the connection is FAILED.
            raise(@terminating_error = @connection.classify_failure(e))
          end

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)

        @current_result = Result.new(@connection, keys, buffer: buffer, handler: handler,
                                     query_text: query, parameters: parameters,
                                     run_metadata: run_response.metadata, fetch_size: fetch_size,
                                     qid: run_response.metadata[:qid],
                                     terminated_error: method(:terminating_error))
        @open_results << @current_result
        @current_result
      end

      def commit
        # Java/JRuby-aligned messages for the already-closed states.
        raise Exceptions::ClientException, 'Can\'t commit, transaction has been committed' if @committed
        raise Exceptions::ClientException, 'Can\'t commit, transaction has been rolled back' if @rolled_back
        raise Exceptions::ClientException, 'Transaction is already closed' unless @open

        if terminated?
          rollback_via_reset
          raise Exceptions::TransactionTerminatedException,
                "Transaction can't be committed. It has been rolled back"
        end

        begin
          discard_open_results
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
            # Classify first so a security failure flags the connection
            # for discard before rollback_via_reset releases it.
            classified = @connection.classify_failure(e)
            rollback_via_reset
            raise classified
          end

        @committed = true
        @open = false

        bookmarks = response.metadata[:bookmark]
        @session.update_bookmarks(bookmarks) if bookmarks
        release_connection
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
        if terminated?
          rollback_via_reset
          return
        end

        begin
          discard_open_results
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
        @connection.fetch_response.assert_success!
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
        @open_results.each do |result|
          begin
            result.consume
          rescue Exceptions::Neo4jException => e
            @failed = true
            # A wire error during PULL streaming (e.g. a reader connection
            # interrupted mid-stream) raises ServiceUnavailable straight from
            # fetch_response, not via Result#on_failure — so it never saw the
            # routing classifier. Run it through here so a routed connection
            # failure surfaces as SessionExpired (idempotent if already classified).
            raise @connection.classify_failure(e)
          end

          # consume is a no-op when the result was already drained by the user;
          # surface any stored failure so callers can react.
          @failed = true if result.failed?
        end
      end

      # Recover a failed transaction by asking the server to RESET the
      # connection. RESET transitions the server from FAILED back to READY
      # and implicitly rolls back the open transaction.
      def rollback_via_reset
        # Skip RESET on a connection being discarded (auth failure: the
        # server closes it, RESET would just error); release then honors
        # the discard flag so it isn't pooled.
        @connection.reset! unless @connection.auth_failed
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
