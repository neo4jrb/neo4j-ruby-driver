# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Handles a single Bolt protocol connection over TCP
      class Connection
        DEFAULT_PORT = 7687
        # Per-read upper bound; the wire reassembles across reads, so this is
        # just how much we ask the socket for at once.
        READ_CHUNK = 65_536

        # The on-demand pull model's response handler: the wire routes a
        # request's reply here (RECORDs then a terminal), and it just collects
        # everything into the shared inbox queue for fetch_response to drain.
        # (A streaming request could register a record-routing handler instead.)
        ResponseCollector = Struct.new(:inbox) do
          def on_record(message)  = inbox.push(message)
          def on_success(message) = inbox.push(message)
          def on_failure(message) = inbox.push(message)
          def on_ignored(message) = inbox.push(message)
          # Failure fan-out is handled connection-wide (inbox closed + @broken_error),
          # so a sync handler needs nothing here.
          def fail(_error); end
        end

        attr_reader :server_version, :server_agent, :protocol, :address
        # idle_since: stamp the pool sets when it pushes a connection
        # back. Bolt::Pool reads it on pop to decide whether to run a
        # liveness probe (idle longer than the configured threshold).
        # created_at: when the TCP/Bolt handshake finished, so the
        # pool can evict connections older than max_connection_lifetime.
        attr_accessor :idle_since, :created_at
        # Set when this connection must not return to the pool — e.g. an
        # auth failure (the server closes the connection after a security
        # FAILURE, and the identity is compromised either way). The direct
        # provider's release discards instead of pooling. (Routing's
        # RoutedConnection carries its own discard_on_release flag.)
        attr_accessor :discard_on_release
        # Set on a security FAILURE specifically: the server closes the
        # connection, so callers must NOT send a RESET (it would error /
        # surface a spurious wire error). Distinct from discard_on_release,
        # which also covers still-alive cases (e.g. NotALeader) that DO
        # want a RESET before the connection is dropped.
        attr_accessor :auth_failed

        # `domain_name_resolver` is the non-public hostname->IPs hook the
        # DriverFactory wires in (default nil = system DNS). It's an explicit
        # dependency, not part of the user `options`, so factory-only
        # extension points never leak into the driver's public config.
        def initialize(uri, auth, options = {}, domain_name_resolver: nil, clock: Internal::Clock.new)
          @uri = URI(uri)
          # The driver's stored auth — the identity HELLO/LOGON
          # authenticated as on connect, and what Session restores via
          # authenticate(driver_auth) when no per-session :auth was
          # given but a previous lessee had switched identity.
          @driver_auth = auth
          @auth = auth
          @options = options
          @clock = clock
          @domain_name_resolver = domain_name_resolver
          @socket = nil
          # The sans-I/O core: framing + hydration, no socket. Built once the
          # handshake has negotiated a protocol (perform_handshake). This
          # Connection is the on-demand pump over it — it owns the socket and
          # moves bytes between it and the wire on the caller's thread.
          @wire = nil
          # The on-demand pull model: every request registers @collector as its
          # response handler on the wire's FIFO; @collector appends each routed
          # message here, and fetch_response drains it. (The handler seam lets a
          # streaming request register a record-routing handler instead.)
          # The dedicated reader is the sole socket reader; it routes each reply
          # to the handler the request registered on the wire's FIFO. Sync
          # replies (RUN/BEGIN/COMMIT/RESET/ROUTE terminals) go to @collector,
          # which pushes them onto @inbox — a blocking queue fetch_response pops.
          # Streaming PULLs register a StreamHandler that fills a RecordBuffer
          # instead. @inbox is a Thread::Queue: the reader pushes, the consumer
          # pops, both colorless (yields under a Fiber scheduler).
          @inbox = Thread::Queue.new
          @collector = ResponseCollector.new(@inbox)
          # LOGOFF/LOGON replies pipelined ahead of the next operation and not yet
          # consumed (Optimization:AuthPipelining).
          @pending_auth_acks = 0
          @recv_timeout = nil # server's connection.recv_timeout_seconds hint
          @read_deadline = nil # monotonic bound for acquisition-phase reads
          # Writes go behind a mutex: the reader writes watermark follow-up
          # nothing — but the consumer writes (new query, next PULL, DISCARD)
          # while the reader reads, so one guarded writer, never two readers.
          @write_mutex = Mutex.new
          # Dedicated reader: a Thread (per-connection lifetime) spawned lazily on
          # the first request, parked on @reader_cv when nothing is in flight,
          # stopped on close. Drives #advance and routes via the wire.
          @reader = nil
          @reader_mutex = Mutex.new
          @reader_cv = ConditionVariable.new       # wakes the reader: a reply is expected
          @quiescent_cv = ConditionVariable.new    # wakes drainers: in_flight hit 0
          @reader_stopped = false
          @broken_error = nil # set by failure fan-out; raised to inbox poppers
          @server_version = nil
          @bolt_version = nil
          @protocol = nil
          @server_agent = nil
          @closed = false
          @created_at = nil
          @idle_since = nil
          @discard_on_release = false
          @auth_failed = false
          @security_notified = false
          @security_classification = nil
          @session_scoped_auth = false
          @auth_epoch = 0
        end

        def connect
          last_error = nil
          # One monotonic acquisition deadline for the whole connect, shared by
          # every resolved-address attempt AND the handshake/HELLO reads: a
          # server stalling the handshake — or a series of stalled addresses —
          # can't collectively outlast the acquisition timeout. Each attempt
          # gets only the *remaining* budget (open_socket / bounded reads). A
          # total deadline (not a per-read timeout) so interleaved NOOP
          # keepalives can't reset the clock. Cleared once the connection is
          # ready and steady-state reads use the recv-timeout hint instead.
          @read_deadline = acquisition_deadline
          resolved_addresses.each do |host, port|
            begin
              open_socket(host, port)
              perform_handshake
              perform_hello
              @read_deadline = nil
              @created_at = current_monotonic
              # Connection is READY: hand steady-state reads to the dedicated
              # reader. (Handshake/hello above read synchronously via
              # fetch_response, so a failed connect never spawns a reader.)
              start_reader
              return self
            rescue Exceptions::AuthenticationException
              # Auth is the same regardless of which address we hit — fail fast.
              discard_socket
              raise
            rescue Exceptions::ServiceUnavailableException, IOError, SystemCallError => e
              last_error = e
              discard_socket
            end
          end

          raise Exceptions::ServiceUnavailableException, 'No addresses to connect to' if last_error.nil?

          # A Neo4jException (e.g. the handshake's ServiceUnavailable) is
          # already classified — propagate as-is. A raw transport error
          # (Errno::ECONNRESET when a plaintext client hits a TLS-only
          # server, EOFError on a mid-handshake close, …) must be wrapped
          # so callers see a DriverError rather than a bare SystemCallError.
          # Without this, native MRI's C-OpenSSL leaks Errno::ECONNRESET and
          # the testkit-backend reports a generic BackendError instead of a
          # DriverError — the one TLS test where mri-on-jruby (whose Java
          # socket layer surfaces a classified error) diverged from native
          # mri (test_secure_server_explicitly_disabled_encryption).
          raise last_error if last_error.is_a?(Exceptions::Neo4jException)

          # Chain the original transport error as `cause` (this raise is
          # outside the per-address rescue, so it's set explicitly rather
          # than auto-populated from $!). Preserves the underlying failure
          # and its backtrace behind the wrapper.
          raise Exceptions::ServiceUnavailableException,
                "Unable to connect to #{@address || @uri}: #{last_error.class}: #{last_error.message}",
                cause: last_error
        end

        # Lightweight RESET-based liveness probe. Used by Bolt::Pool
        # when an idle connection has been parked longer than the
        # configured liveness threshold and we want to confirm it's
        # still usable before handing it to a session. Any wire error
        # OR a non-SUCCESS RESET response → return false; the pool
        # discards and creates a fresh one.
        # NOT reset! — that swallows errors so the original failure
        # surfaces on the next user-driven call; here we want the
        # probe itself to report the outcome. assert_success! is
        # needed because fetch_response returns Message::Failure /
        # Message::Ignored objects without raising — a "soft" RESET
        # failure would otherwise leave the connection in the pool.
        def alive?
          return false if closed?

          send_message(Message.reset)
          flush
          drain_quiesced.each(&:assert_success!)
          true
        rescue StandardError
          discard_socket
          @closed = true
          false
        end

        # Cheap, non-blocking "did the peer go away?" check the pool runs before
        # reusing an idle pooled connection. Unlike alive?, no RESET round-trip:
        # a clean idle connection has nothing to read, so one non-blocking read
        # returns :wait_readable and we're done. A server that closed the idle
        # connection (e.g. a router that served a table then EXITed —
        # test_should_successfully_acquire_rt_when_router_ip_changes) shows up as
        # EOF here, so the pool discards it and the next acquire re-resolves and
        # reconnects. NOOP keepalives are drained harmlessly. This is the
        # threaded equivalent of the reactor's background reader noticing an
        # idle close — without a reader per parked connection.
        def broken?
          return true if closed?

          loop do
            case (chunk = @socket.read_nonblock(READ_CHUNK, exception: false))
            when :wait_readable, :wait_writable
              return false # nothing pending → healthy
            when nil
              mark_closed_broken
              return true # peer closed
            else
              @wire.receive(chunk) # NOOP / stray bytes — drain and re-check
            end
          end
        rescue IOError, SystemCallError
          mark_closed_broken
          true
        end

        # Monotonic seconds — immune to wall-clock jumps, which is what every
        # age / idle calculation here needs. Through the Clock seam so
        # Backend:MockTime can freeze/advance it.
        def current_monotonic
          @clock.monotonic
        end

        def close
          return if @closed

          @closed = true
          # Best-effort GOODBYE before we tear down. Frame+write directly rather
          # than via send_message (which would re-arm the reader) / fetch (GOODBYE
          # has no reply). Then stop the reader and close the socket.
          begin
            @wire&.enqueue(Message.goodbye, @collector)
            bytes = @wire&.take_outbound
            @write_mutex.synchronize { @socket.write(bytes); @socket.flush } if bytes && !bytes.empty?
          rescue StandardError
            # closing anyway
          end
          stop_reader
          @socket&.close rescue nil
        end

        def closed?
          @closed || @socket&.closed?
        end

        # Current auth identity (set by HELLO/LOGON, updated by
        # `authenticate`) and the driver's stored identity (set once at
        # construction). Sessions read driver_auth as the "no per-
        # session :auth was given" default — calling
        # authenticate(driver_auth) on every acquire makes the pool's
        # auth-bleed problem disappear without needing connection-pin
        # bookkeeping.
        attr_reader :auth, :driver_auth

        # The auth "generation" this connection last authenticated at.
        # The provider bumps its own counter on an AuthorizationExpired
        # failure (the server invalidated its authorization cache for every
        # connection of this identity); a pooled connection authed at an
        # older generation must re-authenticate on next acquire even though
        # its token is unchanged. Set by the provider's connect_factory /
        # ensure_identity.
        attr_accessor :auth_epoch

        # Bolt 5.1+ re-auth: LOGOFF then LOGON with `new_auth`. Used by
        # Session when it has its own `:auth` and the pooled connection
        # is currently authenticated as somebody else. No-op when the
        # connection already holds the target identity — unless `force`
        # (an AuthorizationExpired-driven refresh re-auths to the *same*
        # token to refresh the server's authorization cache).
        def authenticate(new_auth, force: false, pipelined: true)
          return if !force && @auth == new_auth
          unless @protocol&.supports_re_auth?
            raise Exceptions::UnsupportedFeatureException,
                  "Per-session auth requires Bolt 5.1+; negotiated #{@bolt_version}"
          end

          send_message(Message.logoff)
          send_message(Message.logon(new_auth || {}))
          @auth = new_auth
          # AuthPipelining: enqueue LOGOFF + LOGON but don't flush or read their
          # replies — they ride out with the next operation's messages and are
          # consumed (via #drain_pending_auth_acks, from the next #fetch_response)
          # just before that operation reads its own reply, saving a round-trip.
          # A rejected LOGON surfaces there as the auth failure (the operation's
          # own message is IGNORED). @auth is set optimistically; a failed re-auth
          # discards the connection, so a stale value never gets reused.
          #
          # pipelined: false forces the synchronous round-trip — verify_authentication
          # re-auths then discards the connection with no operation to carry (and
          # drain) the replies, and must see the LOGON's success/failure itself.
          if pipelined
            @pending_auth_acks += 2
          else
            flush
            fetch_response.assert_success!
            fetch_response.assert_success!
          end
        end

        # True when the connection's current identity came from a per-session
        # auth token rather than the auth-token manager's default. The manager
        # didn't issue that token, so a security failure on such a connection
        # must NOT be reported to it (testkit's get_auth contract:
        # handle_security_exception_count stays 0 for session-scoped auth).
        # Set by the provider's ensure_identity on every acquire so it tracks
        # the current lessee of a reused pooled connection.
        attr_accessor :session_scoped_auth

        # Provider-set callback (token, error) -> Boolean: feeds a
        # security failure back to the auth-token manager so it can
        # invalidate / refresh the token. nil for drivers built without a
        # managed manager (the static case never invalidates).
        attr_accessor :security_exception_handler

        # Report a security failure to the auth-token manager (if any) and
        # let it decide retryability. Every operation site funnels errors
        # through classify_failure, so this is the single notification
        # point. When the manager deems the failure retryable (it has
        # invalidated the token so the next acquire re-fetches), surface a
        # SecurityRetryableException wrapping the original (code/message
        # preserved, original chained as cause when the caller re-raises)
        # — mirrors Java, and the testkit reports it as retryable.
        def notify_security_exception(error)
          return error unless error.is_a?(Exceptions::SecurityException)

          # A security failure means this connection can't be reused — drop
          # it from the pool either way.
          @discard_on_release = true

          # AuthorizationExpired is the server's authorization-cache expiry,
          # not a closed socket — the connection stays usable, so RESET is
          # fine. Unauthorized / TokenExpired close the connection server-
          # side, so skip RESET there.
          @auth_failed = true unless error.is_a?(Exceptions::AuthorizationExpiredException)

          # Notify the auth-token manager at most once per connection. The
          # same failure is classified again as it propagates (result
          # streaming on_failure, then the tx rollback re-consuming the
          # failed result), so without this guard the manager's
          # handle_security_exception fires twice. We also cache the
          # classified result and return it on the repeat calls, so the
          # retryability/type stays stable — the first call may upgrade to
          # SecurityRetryableException, and a later call must not downgrade
          # back to the raw error. The connection is discarded after a
          # security failure, so neither the flag nor the cache needs
          # clearing.
          return @security_classification if @security_notified

          @security_notified = true
          # Always run the provider handler — it performs provider-side work
          # that must happen regardless of who owns the token, notably bumping
          # the auth epoch on AuthorizationExpired so SIBLING pooled
          # connections re-authenticate. `session_scoped_auth` is passed so the
          # handler can skip the auth-token-MANAGER notification for a
          # per-session identity (the manager didn't issue that token, so its
          # handle_security_exception_count must stay 0). A retryable verdict
          # surfaces a SecurityRetryableException wrapping the original
          # (code/message preserved, original chained as cause at re-raise);
          # the handler returns false for session-scoped auth, so no upgrade.
          @security_classification =
            if @security_exception_handler&.call(@auth, error, @session_scoped_auth)
              Exceptions::SecurityRetryableException.new(error.message, code: error.code)
            else
              error
            end
        end

        # No-op routing classifier for the direct (bolt://) path — there's
        # no routing table to feed back. Still funnels through the auth
        # manager. Routing::RoutedConnection overrides with the real
        # routing classification (and also notifies). Defined here so
        # session.rb / transaction.rb / Result#on_failure can call
        # `connection.classify_failure(e)` unconditionally.
        def classify_failure(error) = notify_security_exception(error)

        # Frame the message into the wire's outbound buffer and count it as
        # in-flight. Nothing hits the socket until #flush — so several
        # send_messages before a flush pipeline naturally (HELLO+LOGON,
        # RUN+PULL), which is the whole point.
        #
        # A dead/closed connection raises a classified Neo4jException, not a raw
        # IOError: the cleanup and retry paths (Transaction#rollback, reset!,
        # the managed-tx retry) rescue Neo4jException, so a bare IOError would
        # escape them and surface as an unhandled error.
        # Register a request on the wire's FIFO with the handler that will route
        # its reply: @collector (→ @inbox) for sync requests, or a StreamHandler
        # (→ a RecordBuffer) for a streaming PULL. The dedicated reader (started
        # once the connection is READY) delivers it; during the acquisition phase
        # (handshake/hello, before the reader exists) fetch_response drives the
        # reads synchronously.
        def send_message(message, handler = @collector)
          raise Exceptions::ServiceUnavailableException, "Connection to #{@address || @uri} is closed" if closed?

          @wire.enqueue(message, handler)
        end

        def send_all(*messages)
          messages.each { |msg| send_message(msg) }
          flush
        end

        # Enqueue a TELEMETRY report for the API about to open a tx/query, unless
        # the caller disabled it, the server didn't advertise telemetry, or the
        # negotiated protocol predates it (5.4). Returns whether one was sent so
        # the caller reads its (extra, pipelined) SUCCESS before the op's reply.
        def telemetry(api, disabled:)
          return false if api.nil? || disabled || !@telemetry_enabled || !@protocol.supports_telemetry?

          send_message(@protocol.build_telemetry(api))
          true
        end

        # Fetch the cluster routing table. Bolt 4.3+ uses the dedicated
        # ROUTE message; older versions have no ROUTE and call a
        # server-side procedure instead (route_via_procedure). Either
        # way the return is the `{ttl:, servers:}` map the caller wraps
        # in Routing::RoutingTable.from_response.
        def route(database: nil, bookmarks: [], imp_user: nil, routing_context: {})
          # Enforce impersonation support before touching the wire: a
          # routed session impersonating against a pre-4.4 cluster must
          # fail (ClientException) rather than silently drop imp_user from
          # the discovery call. Raised here — outside the wire-error
          # begin/rescue — so the still-clean connection isn't RESET.
          @protocol.enforce_impersonation_support!(imp_user)

          return route_via_procedure(database, bookmarks, routing_context) if @bolt_version < BoltVersion::V4_3

          begin
            # ROUTE's 3rd field changed at 4.4: 4.3 sends the bare database
            # name (string/null), 4.4+ a `{db, imp_user}` map. The protocol
            # handler owns that shape. The acquisition timeout must encompass
            # discovery, so bound the ROUTE read by the deadline (cleared after).
            @read_deadline = acquisition_deadline
            send_message(@protocol.build_route(routing_context, Array(bookmarks), database, imp_user))
            flush

            fetch_response.assert_success!.metadata[:rt]
          rescue Exceptions::Neo4jException
            # ROUTE failure leaves the server in FAILED state — RESET clears it
            # so the connection can be reused.
            reset!
            raise
          ensure
            @read_deadline = nil
          end
        end

        # Pre-4.3 routing: there is no ROUTE message, so fetch the table
        # by calling the server-side procedure and shaping its single
        # row ([ttl, servers]) into the same map ROUTE would return.
        #   Bolt 3.0:    CALL dbms.cluster.routing.getRoutingTable($context)
        #                on the home database (single-DB protocol).
        #   Bolt 4.0-4.2: CALL dbms.routing.getRoutingTable($context, $database)
        #                run against the `system` database.
        def route_via_procedure(database, bookmarks, routing_context)
          if @bolt_version >= BoltVersion::V4_0
            # 4.0-4.2: dbms.routing.getRoutingTable run against `system`.
            # Pass $database only when a target db is named — the home-db
            # case uses the single-arg form (matches the server procedure
            # overloads the stub scripts pin).
            if database
              query = 'CALL dbms.routing.getRoutingTable($context, $database)'
              params = { context: routing_context, database: database }
            else
              query = 'CALL dbms.routing.getRoutingTable($context)'
              params = { context: routing_context }
            end
            extra = { db: 'system', mode: 'r' }
            # 4.0-4.2 runs the procedure against `system`, which accepts
            # bookmarks (causal consistency for a freshly-created database).
            extra[:bookmarks] = Array(bookmarks) unless Array(bookmarks).empty?
          else
            # 3.0: single-database cluster routing procedure, home db. No
            # system db and no bookmark-aware routing (that arrived with the
            # 4.3 ROUTE message), so the discovery RUN carries only `mode`.
            query = 'CALL dbms.cluster.routing.getRoutingTable($context)'
            params = { context: routing_context }
            extra = { mode: 'r' }
          end

          send_message(@protocol.build_run(query, params, extra))
          send_message(@protocol.build_pull(n: -1))
          flush

          summary = fetch_response.assert_success!
          fields = summary.metadata[:fields] || summary.metadata['fields'] || []
          row = nil
          loop do
            response = fetch_response
            case response
            when Message::Success then break # PULL summary — end of stream
            when Message::Record  then row ||= fields.zip(response.fields).to_h
            else response.assert_success! # FAILURE / IGNORED — raises
            end
          end

          unless row
            raise Exceptions::ServiceUnavailableException,
                  "Routing procedure on #{@address || @uri} returned no rows"
          end

          { ttl: row['ttl'], servers: row['servers'] }
        rescue Exceptions::Neo4jException
          reset!
          raise
        end

        # Defer peer-closed errors from flush so a buffered server
        # response (e.g. a final FAILURE) gets read before we raise.
        # Under JRuby the peer-closed state surfaces eagerly on the
        # very next write/flush; raising here would swallow the
        # FAILURE bytes already in the receive buffer — the
        # test_should_error_on_database_shutdown_using_tx_run stub
        # regression. Every normal request/response cycle pairs flush
        # with a fetch_response (Transaction#run/commit/rollback,
        # Result streaming, Connection#route), so a peer-gone state
        # with nothing buffered still surfaces as
        # ServiceUnavailableException — just from the read side.
        # Connection#close also calls flush but discards exceptions
        # itself (`flush rescue nil`), so it does not need the pair.
        # Non-peer-closed wire errors (e.g. a timed-out write on a
        # socket that has SO_SNDTIMEO set, or EBADF on a
        # closed-out-from-under-us fd) are NOT silenced — they fall
        # through and propagate. We do not set SO_SNDTIMEO and the fd
        # is owned by us, so these are improbable in practice.
        # Drain the wire's outbound buffer to the socket. Writes are mutex-
        # guarded so a future prefetch reader and the consumer's writes never
        # interleave on one socket. Peer-closed errors are deferred (not raised)
        # so a server FAILURE buffered before the close is still read by the
        # paired fetch_response — every request/response cycle pairs flush with
        # a fetch (Transaction#run/commit/rollback, Result streaming, #route),
        # so a genuinely-gone peer still surfaces as ServiceUnavailable from the
        # read side. #close flushes with `rescue nil`, so it needs no pair.
        def flush
          bytes = @wire.take_outbound
          return if bytes.empty?

          begin
            @write_mutex.synchronize do
              @socket.write(bytes)
              @socket.flush
            end
          rescue Errno::EPIPE, Errno::ECONNRESET, IOError
            # Peer-closed (EPIPE/ECONNRESET) or the reader closed the socket
            # out from under this write mid-flight (IOError "stream closed in
            # another thread", EBADF). Deferred (not raised) so a server FAILURE
            # buffered before the close is still read by the paired
            # fetch_response — see method comment.
          ensure
            # Always wake the reader, even on a failed write: a reply may be
            # expected, OR the socket is dead and the reader must run #advance to
            # hit EOF and fan the failure out — otherwise a parked reader never
            # discovers the break and a drainer in #wait_quiescent hangs.
            wake_reader
          end
        end

        # Return the next sync reply in request order. The dedicated reader fills
        # @inbox (a blocking queue); this pops it, blocking colorlessly until the
        # reader delivers. On a connection failure the reader closes @inbox and
        # records @broken_error, so a blocked pop wakes with nil and re-raises the
        # classified error rather than hanging.
        def fetch_response
          # A pipelined re-auth's LOGOFF/LOGON replies sit ahead of this
          # operation's own reply — consume them first (AuthPipelining).
          drain_pending_auth_acks
          pop_inbox
        end

        # Pop the next sync reply. Acquisition phase (no reader yet): drive the
        # reads ourselves. Steady state: the reader fills @inbox; block on pop
        # until it delivers. On a connection failure the reader closes @inbox and
        # records @broken_error, so a blocked pop wakes with nil and re-raises.
        def pop_inbox
          advance while @reader.nil? && @inbox.empty?
          message = @inbox.pop
          raise @broken_error if message.nil? && @broken_error

          message
        end

        # Consume the replies to a pipelined re-auth's LOGOFF + LOGON before the
        # next operation reads its own reply. A rejected LOGON raises the auth
        # failure here (its follow-on messages come back IGNORED).
        def drain_pending_auth_acks
          return if @pending_auth_acks.zero?

          pending = @pending_auth_acks
          @pending_auth_acks = 0
          pending.times { pop_inbox.assert_success! }
        end

        def fetch_all
          drain_quiesced
        end

        # Recover from a FAILED server state. Sends RESET and drains all pending
        # responses (including any IGNOREDs from messages queued before the
        # failure — those routed to their handlers; this drains the sync @inbox).
        # Returns once the server has acknowledged the RESET and the connection is
        # quiescent.
        def reset!(propagate: false)
          send_message(Message.reset)
          flush
          messages = drain_quiesced
          # When propagating (verify_connectivity, pool-return) the RESET is a
          # real check: a server FAILURE reply (not just a dead socket) must
          # surface too, so assert success on the drained responses.
          messages.each(&:assert_success!) if propagate
        rescue StandardError
          # If RESET itself fails the connection is likely dead. Recovery paths
          # (`propagate: false`, the default) swallow so they don't mask the
          # original error and the caller discovers the break on next use.
          # verify_connectivity passes `propagate: true`: the RESET *is* the
          # probe, so a failure must surface (and the dead connection be
          # discarded) rather than report false success.
          raise if propagate
        ensure
          # RESET flushed and drained any pipelined re-auth replies with it.
          @pending_auth_acks = 0
        end

        # True while the caller still owes a fetch: a request whose terminal the
        # wire hasn't seen yet (in_flight), or a message already routed to the
        # inbox but not yet popped. The drain loops spin on this.
        def pending_responses?
          @wire.in_flight.positive? || !@inbox.empty?
        end

        private

        def discard_socket
          stop_reader
          @socket&.close rescue nil
          @socket = nil
          # Reset all per-attempt I/O state so a retry on the next address (or a
          # later reset!/drain loop) doesn't carry a phantom in-flight request or
          # half-parsed message forward. @wire (with its handler FIFO) is rebuilt
          # by perform_handshake. A fresh @inbox (the old one may be closed by a
          # fan-out) and cleared reader/broken state so a retry can re-arm the
          # reader. Crucially clear @closed too: a fail_broken on one address set
          # it, and connect() retries the next address with a fresh socket —
          # without this, send_message there would wrongly raise "Connection is
          # closed" and break address failover.
          @wire = nil
          @inbox = Thread::Queue.new
          # Rebind the collector to the fresh inbox — it captured the old queue
          # at init, so without this a retry's sync replies would land in the
          # discarded queue while fetch_response waits on the new one.
          @collector = ResponseCollector.new(@inbox)
          @reader_stopped = false
          @broken_error = nil
          @closed = false
        end

        # One colorless pump step: pull whatever bytes are available off the
        # socket and feed them to the wire, which routes any decoded messages to
        # the front handler (today: @collector → @inbox). A step may land several
        # messages, one, or none (a partial chunk or a NOOP keepalive) — callers
        # loop until what they need has arrived (fetch_response: @inbox non-empty).
        #
        # read_nonblock(exception: false) returns the bytes, :wait_readable/
        # :wait_writable when it would block, or nil on EOF. The explicit wait
        # honors the recv timeout (readpartial/read ignore IO#timeout for partial
        # reads) and yields under a Fiber scheduler (wait_readable hooks io_wait),
        # so the pump is colorless. The dedicated reader loops this.
        def advance
          case (chunk = @socket.read_nonblock(READ_CHUNK, exception: false))
          when :wait_readable
            @socket.wait_readable(current_read_timeout) or fail_broken(read_timeout_error)
          when :wait_writable # SSL renegotiation mid-read
            @socket.wait_writable(current_read_timeout) or fail_broken(read_timeout_error)
          when nil
            raise EOFError, 'end of file reached'
          else
            @wire.receive(chunk)
          end
        rescue IOError, SystemCallError => e
          fail_broken(Exceptions::ServiceUnavailableException.new(
                        "Connection to #{@address || @uri} broken: #{e.class}: #{e.message}"))
        end

        # The dedicated reader: the sole socket reader for this connection's
        # lifetime. It advances (reads + routes via the wire) while replies are
        # in flight, and parks on @reader_cv when none are — woken by #flush when
        # a request is sent, or by #stop_reader on close. Any read failure is
        # fanned out to every waiter (see #fan_out). A plain Thread: it does
        # blocking I/O and feeds colorless queues/buffers, so a consumer fiber
        # under a host scheduler still yields on pop/shift. (The reactor-native
        # fiber reader + per-active-window lifetime is a later step.)
        def reader_loop
          until @reader_stopped
            @reader_mutex.synchronize do
              # in_flight == 0 ⇒ all expected replies are read: the connection is
              # quiescent. Wake any drainer (reset!/fetch_all/alive?) before we park.
              @quiescent_cv.broadcast if @wire.in_flight.zero?
              @reader_cv.wait(@reader_mutex) while !@reader_stopped && @wire.in_flight.zero?
            end
            # Woken to read — unless we were woken to stop (don't advance on the
            # socket #stop_reader just closed; that would fan out a phantom error).
            advance unless @reader_stopped
          end
        rescue StandardError => e
          fan_out(e)
        end

        # Block until the connection is quiescent (the reader has read every
        # in-flight reply, wherever it routed — @inbox or a stream buffer) or it
        # broke. The drain loops use this instead of racing on in_flight.
        def wait_quiescent
          @reader_mutex.synchronize do
            @quiescent_cv.wait(@reader_mutex) until @wire.in_flight.zero? || @reader_stopped || @broken_error
          end
        end

        # Wait for quiescence, then pop every sync reply sitting in @inbox
        # (non-blocking). Stream replies went to their buffers, not here.
        def drain_quiesced
          wait_quiescent
          raise @broken_error if @broken_error

          messages = []
          loop { messages << @inbox.pop(true) }
        rescue ThreadError, ClosedQueueError
          messages || []
        end

        # Start the dedicated reader once the connection is READY (called at the
        # end of connect). Idempotent; never re-armed once stopped.
        def start_reader
          return if @reader || @reader_stopped

          @reader = Thread.new { reader_loop }
        end

        # Wake a parked reader: a reply is now expected (a request was flushed).
        def wake_reader
          @reader_mutex.synchronize { @reader_cv.broadcast }
        end

        # Stop the reader and wait for it to exit. Closing the socket unblocks a
        # reader parked in advance's wait_readable; the stopped flag + broadcast
        # unblocks one parked on @reader_cv.
        def stop_reader
          reader = @reader
          @reader = nil
          # Wake the parked reader (@reader_cv) and any drainer blocked in
          # #wait_quiescent (@quiescent_cv) — stopping is a terminal transition
          # they must observe, else a concurrent reset!/fetch_all/alive? hangs.
          @reader_mutex.synchronize { @reader_stopped = true; @reader_cv.broadcast; @quiescent_cv.broadcast }
          return unless reader

          @socket&.close rescue nil
          reader.join unless reader == Thread.current
        end

        # Failure fan-out: a dead/timed-out connection must wake every waiter,
        # not just the front one. Record the classified error, close @inbox so
        # sync poppers (fetch_response) return nil → re-raise it, fail each
        # outstanding stream buffer (via its handler) so a cursor parked in
        # buffer.await wakes and re-raises too, and broadcast @quiescent_cv so a drainer
        # parked in #wait_quiescent (reset!/fetch_all/alive?) wakes on the
        # @broken_error condition instead of waiting forever for an in-flight
        # reply that will never arrive. Idempotent; may run on the reader thread
        # (reader_loop rescue) or the consumer thread (flush write failure).
        def fan_out(error)
          @broken_error ||= error
          @inbox.close
          @wire&.fail_pending(error)
          mark_closed_broken
          @reader_mutex.synchronize { @quiescent_cv.broadcast }
        end

        # A read timeout or wire error means this connection is unusable: hang
        # up (so the peer sees the disconnect — the recv-timeout contract
        # asserts the driver hangs up a timed-out connection) and mark it closed
        # so the pool discards it on the next acquire rather than reusing a
        # broken connection. Then raise the classified error.
        def fail_broken(error)
          mark_closed_broken
          raise error
        end

        def mark_closed_broken
          @socket&.close rescue nil
          @closed = true
        end

        # The timeout the next read may take. During acquisition (handshake,
        # ROUTE) it's the remaining budget of the total deadline; in steady
        # state it's the server's recv-timeout hint (nil = block indefinitely).
        def current_read_timeout
          return [@read_deadline - current_monotonic, 0.001].max if @read_deadline

          @recv_timeout
        end

        # A read timeout means different things in different phases: during
        # acquisition the connection-acquisition budget was exceeded (a generic
        # ServiceUnavailable); in steady state the server breached its own
        # recv-timeout hint (the specific ConnectionReadTimeoutException, which
        # routing turns into server eviction). Fresh instance per failure.
        def read_timeout_error
          if @read_deadline
            Exceptions::ServiceUnavailableException.new(
              "Timed out acquiring a connection to #{@address || @uri} within the acquisition timeout"
            )
          else
            Exceptions::ConnectionReadTimeoutException.new(
              'Connection read timed out due to it taking longer than the server-supplied timeout value via configuration hint.'
            )
          end
        end

        # Monotonic deadline from the connection-acquisition timeout (nil when
        # unconfigured). Bounds the handshake and ROUTE reads so a stalled
        # server can't outlast the acquisition budget.
        def acquisition_deadline
          acq = @options[:connection_acquisition_timeout]&.to_f
          acq && current_monotonic + acq
        end

        # Seconds left until the shared acquisition deadline (@read_deadline),
        # clamped at 0; nil when the acquisition timeout is unconfigured. Used
        # to give each connect attempt only the remaining budget.
        def remaining_read_budget
          @read_deadline && [@read_deadline - current_monotonic, 0.0].max
        end

        # Resolve the URI's host:port into a list of [host, port] pairs to try
        # in order. Hosts are kept in their native form — IPv6 stays bracketed
        # ("[::1]") so address strings re-parse unambiguously; brackets are
        # only stripped at the TCPSocket boundary.
        # With a `domain_name_resolver` (Java's DomainNameResolver), the
        # callable receives the hostname and returns one or more IPs, each
        # paired with the original port. The custom *address* resolver
        # (ServerAddressResolver) is a separate, routing-only concern handled
        # by the LoadBalancer, not here.
        def resolved_addresses
          host = @uri.host
          port = @uri.port || DEFAULT_PORT

          # Domain-name resolution (hostname -> one or more IPs) happens at
          # connect time, on every connection. The custom *address* resolver
          # (ServerAddressResolver) is a separate, routing-only concern that
          # expands the seed into initial routers — applied by the
          # LoadBalancer, not here (Java draws the same line).
          if @domain_name_resolver
            Array(@domain_name_resolver.call(host)).map { |ip| [ip.to_s, port] }
          else
            [[host, port]]
          end
        end

        def split_addr(addr, default_port)
          # rpartition handles IPv6: "[::1]:7687" -> ["[::1]", ":", "7687"]
          host, sep, port = addr.to_s.rpartition(':')
          sep.empty? ? [addr.to_s, default_port] : [host, Integer(port)]
        end

        def format_address(host, port)
          # Wrap raw IPv6 (`::1`) in brackets so the result re-parses correctly.
          host = "[#{host}]" if host.include?(':') && !host.start_with?('[')
          "#{host}:#{port}"
        end

        def strip_brackets(host)
          host&.start_with?('[') && host.end_with?(']') ? host[1..-2] : host
        end

        def open_socket(host, port)
          timeout = @options[:connection_timeout]
          bare_host = strip_brackets(host)
          # Bound the TCP connect by the smaller of the connection timeout and
          # the REMAINING acquisition budget (the shared @read_deadline), so
          # acquisition_timeout caps a connect to a non-responsive/non-routable
          # address — not just the handshake reads — and retries across
          # addresses can't collectively exceed it (testkit
          # test_should_fail_when_acquisition_timeout_is_reached_first, where
          # acquisition 2s < connection 720s).
          connect_timeout = [timeout&.to_f, remaining_read_budget].compact.min
          tcp_socket = connect_timeout ? Socket.tcp(bare_host, port, connect_timeout: connect_timeout) : TCPSocket.new(bare_host, port)
        rescue SystemCallError, SocketError => e
          raise Exceptions::ServiceUnavailableException,
                "Unable to connect to #{format_address(host, port)}, ensure the database is running and that there is a working network connection to it. (#{e.message})"
        else
          @address = format_address(host, port)
          tcp_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

          if timeout
            timeval = [timeout, 0].pack('l_2')
            tcp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, timeval)
            tcp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, timeval)
          end

          @socket = wrap_with_tls(tcp_socket, bare_host, port)
        end

        # When the URI uses a +s/+ssc scheme (or :encryption is set
        # explicitly), wrap the TCP socket in an OpenSSL::SSL::SSLSocket
        # before returning. Errors during the TLS handshake — peer
        # certificate refused, hostname mismatch, server doesn't speak
        # TLS — turn into Neo4j-shaped exceptions so the caller doesn't
        # have to know whether the wire is encrypted.
        def wrap_with_tls(tcp_socket, hostname, port)
          tls = TlsConfig.new(uri: @uri, options: @options)
          ctx = tls.ssl_context
          return tcp_socket unless ctx

          ssl = OpenSSL::SSL::SSLSocket.new(tcp_socket, ctx)
          ssl.sync_close = true
          ssl.hostname = hostname # SNI
          ssl.connect
          ssl.post_connection_check(hostname) if tls.verify_hostname?
          ssl
        rescue OpenSSL::SSL::SSLError => e
          tcp_socket.close rescue nil
          raise Exceptions::SecurityException,
                "TLS handshake to #{format_address(hostname, port)} failed: #{e.message}"
        rescue SystemCallError, IOError => e
          tcp_socket.close rescue nil
          raise Exceptions::ServiceUnavailableException,
                "Connection lost during TLS handshake to #{format_address(hostname, port)}: #{e.message}"
        end

        def perform_handshake
          # Bound the (raw, pre-wire) version negotiation by the acquisition
          # deadline too, so a server that stalls the magic-byte exchange can't
          # outlast it. Handshake reads via wait_readable, so the bound fires on
          # JRuby as well as CRuby (read()+IO#timeout would not).
          agreed_version = Handshake.new(@socket, deadline: @read_deadline, clock: @clock).negotiate
          @server_version = agreed_version
          @bolt_version = BoltVersion.from_int(agreed_version)
          @protocol = ProtocolVersionHandler.for_version(self, agreed_version)
          # Stand up the sans-I/O core now that a protocol is negotiated: it
          # configures the packer (UTC datetime flag) and owns hydration.
          @wire = Wire.new(@protocol)

          puts "Negotiated Bolt version: #{@bolt_version} (0x#{agreed_version.to_s(16)})" if ENV['DEBUG']
        end

        def perform_hello
          auth_hash = case @auth
                      when Hash
                        @auth
                      else
                        {}
                      end

          # Use protocol handler to build version-specific HELLO message.
          # `routing_context` is set by Routing::LoadBalancer (nil for
          # direct bolt:// drivers); the protocol handler drops it from
          # the HELLO payload when nil. `user_agent` may be overridden by
          # the caller (testkit threads its configured agent through the
          # driver options). On Bolt 5.1+ the HELLO carries no auth —
          # @protocol.build_hello_message strips it and we send a
          # separate LOGON below.
          hello_msg = @protocol.build_hello_message(
            user_agent: @options[:user_agent] || "neo4j-ruby-driver/#{Neo4j::Driver::VERSION}",
            auth: auth_hash,
            routing: @options[:routing_context],
            # Driver-level NotificationsConfig; only reaches the wire on Bolt
            # 5.2+ (older protocols return {} from notification_config_extra).
            notification_config: @options[:notification_config]
          )

          # Pipeline HELLO and (on 5.1+) LOGON: enqueue both, flush once, then
          # read both replies. A pipelined server answers only once it has the
          # whole handshake (the recv-timeout liveness stub is C: HELLO / C:
          # LOGON / S: SUCCESS / S: SUCCESS), so reading HELLO's reply before
          # sending LOGON would deadlock. On 5.0/4.x build_logon_message is nil
          # — auth went in the HELLO map — and this is a single round-trip.
          logon_msg = @protocol.build_logon_message(auth_hash)
          send_message(hello_msg)
          send_message(logon_msg) if logon_msg
          flush

          hello = fetch_response.assert_success!
          @server_agent = hello.metadata[:server]
          # Bolt 4.3/4.4 UTC patch: if the server confirmed `patch_bolt: ["utc"]`
          # (we advertised it in HELLO), switch datetime packing to UTC-seconds
          # (0x49/0x69). Native on 5.0+, so this only ever fires on 4.3/4.4.
          @wire.enable_utc_datetime if Array(hello.metadata[:patch_bolt]).include?('utc')
          # The server may advertise connection.recv_timeout_seconds in HELLO's
          # SUCCESS hints; from now a steady-state read that exceeds it is a
          # broken connection (ConnectionReadTimeoutException).
          apply_recv_timeout_hint(hello.metadata[:hints])
          # `telemetry.enabled` hint (Bolt 5.4+) opts the server into receiving
          # TELEMETRY reports; without it the driver stays silent.
          @telemetry_enabled = hello.metadata.dig(:hints, :'telemetry.enabled') == true

          fetch_response.assert_success! if logon_msg
        end

        def apply_recv_timeout_hint(hints)
          seconds = hints && hints[:'connection.recv_timeout_seconds']
          @recv_timeout = seconds if seconds&.positive?
        end

      end
    end
  end
end
