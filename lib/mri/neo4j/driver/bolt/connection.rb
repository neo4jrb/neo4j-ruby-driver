# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Handles a single Bolt protocol connection over TCP
      class Connection
        DEFAULT_PORT = 7687

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
        def initialize(uri, auth, options = {}, domain_name_resolver: nil, reactor: nil)
          @uri = URI(uri)
          # The driver's stored auth — the identity HELLO/LOGON
          # authenticated as on connect, and what Session restores via
          # authenticate(driver_auth) when no per-session :auth was
          # given but a previous lessee had switched identity.
          @driver_auth = auth
          @auth = auth
          @options = options
          @domain_name_resolver = domain_name_resolver
          # The driver's IO engine. Owns the thread/reactor the reader and
          # writer fibers run on. Defaulted so bare Connection.new in tests
          # still works without a provider wiring one in.
          @reactor = reactor || Reactor.new
          @socket = nil
          @packer = PackStream::Packer.new
          @server_version = nil
          @bolt_version = nil
          @protocol = nil
          @server_agent = nil
          @created_at = nil
          @idle_since = nil
          @discard_on_release = false
          @auth_failed = false
          @security_notified = false
          @security_classification = nil
          @session_scoped_auth = false
          @auth_epoch = 0

          # --- Pipelined IO state (see docs/pipelined-connection.md) -------
          # @write_queue : framed message bytes the writer fiber drains.
          # @responses   : parsed responses the reader fiber delivers, popped
          #                in request order by fetch_response. A dead socket
          #                pushes the classified exception here (fan-out).
          # Both are scheduler-aware Thread::Queues so a caller bridges in
          # whether it's a plain thread (blocks) or a fiber (yields).
          @write_queue = Thread::Queue.new
          @responses = Thread::Queue.new
          @reader_task = nil
          @writer_task = nil
          # @io_mutex guards the cross-thread fields below (caller thread vs.
          # reactor thread): everything else is single-owner.
          @io_mutex = Mutex.new
          @closed = false
          @torn_down = false   # #close ran (stopped fibers, closed socket)
          @dead = nil          # the exception a dead socket fanned out
          @recv_timeout = nil  # server's connection.recv_timeout_seconds hint
          @read_deadline = nil # monotonic deadline bounding the synchronous handshake
          @awaiting = 0        # messages sent whose terminal the reader hasn't read
          @inflight = 0        # messages sent whose terminal the caller hasn't consumed
        end

        def connect
          last_error = nil
          resolved_addresses.each do |host, port|
            begin
              open_socket(host, port)
              # Handshake + HELLO/LOGON are raw, synchronous round-trips on the
              # caller thread; the reader/writer fibers take over the socket only
              # once the connection is authenticated. Doing HELLO/LOGON before
              # start_io means the server's recv-timeout hint is in hand before
              # the reader ever waits on a reply — no race over which timeout the
              # first post-handshake read uses. (HELLO+LOGON are still pipelined:
              # both are written before either reply is read, which is what the
              # recv-timeout liveness stub requires.) The whole synchronous
              # handshake is bounded by one acquisition deadline — a total
              # deadline, not a per-read timeout, so a server dripping bytes or
              # NOOP keepalives can't reset the clock and outlast it.
              @read_deadline = acquisition_deadline
              @socket.timeout = remaining_handshake_budget
              perform_handshake
              perform_hello
              @read_deadline = nil
              start_io
              @created_at = current_monotonic
              return self
            rescue Exceptions::AuthenticationException
              # Auth is the same regardless of which address we hit — fail fast.
              teardown_io
              raise
            rescue Exceptions::ServiceUnavailableException, IOError, SystemCallError => e
              last_error = e
              teardown_io
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
          fetch_response.assert_success! while pending_responses?
          true
        rescue StandardError
          teardown_io
          mark_closed
          false
        end

        # Monotonic seconds — immune to wall-clock jumps, which is
        # what every age / idle calculation here needs.
        def current_monotonic
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # Tear down the connection exactly once. Stops the reader/writer and
        # closes the socket on the reactor thread that owns them (stopping a
        # fiber and closing its fd from a foreign thread is unsafe). Runs even
        # for an already-dead connection (closed? is true after a wire failure)
        # so the pool's discard reaps the still-parked sibling fiber. A live
        # connection first sends a best-effort GOODBYE; a dead one skips it.
        def close
          return if @torn_down

          @torn_down = true
          mark_closed
          goodbye = (framed_message(Message.goodbye) unless @io_mutex.synchronize { @dead }) rescue nil
          reader = @reader_task
          writer = @writer_task
          socket = @socket

          @reactor.run_and_wait do
            writer&.stop
            begin
              if goodbye
                socket.write(goodbye)
                socket.flush
              end
            rescue StandardError
              # peer already gone — nothing to gain from GOODBYE
            end
            reader&.stop
            socket&.close
          end
        rescue StandardError
          @socket&.close rescue nil
        end

        def closed?
          @io_mutex.synchronize { @closed } || @socket&.closed?
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
        def authenticate(new_auth, force: false)
          return if !force && @auth == new_auth
          unless @protocol&.supports_re_auth?
            raise Exceptions::UnsupportedFeatureException,
                  "Per-session auth requires Bolt 5.1+; negotiated #{@bolt_version}"
          end

          send_message(Message.logoff)
          send_message(Message.logon(new_auth || {}))
          flush
          fetch_response.assert_success!
          fetch_response.assert_success!
          @auth = new_auth
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

        # Pack + frame the message on the caller thread (bounded CPU, kept off
        # the reactor) and hand the bytes to the writer fiber. Returns
        # immediately — the response is collected lazily by the reader and read
        # back via fetch_response. This is what makes the wire pipelined: a
        # caller can enqueue several messages (HELLO+LOGON, RUN+PULL) before it
        # reads a single reply.
        def send_message(message)
          # A dead/closed connection raises a classified Neo4jException, not a
          # bare IOError — the cleanup and retry paths (Transaction#rollback,
          # reset!, the managed-tx retry) all rescue Neo4jException, so a raw
          # IOError here would escape them and surface as an unhandled backend
          # error. Reuse the fan-out exception when there is one (it carries the
          # real cause: a recv-timeout, a dropped socket).
          dead = @io_mutex.synchronize { @dead }
          raise dead if dead
          raise Exceptions::ServiceUnavailableException, "Connection to #{@address || @uri} is closed" if closed?

          bytes = framed_message(message)
          @io_mutex.synchronize { @awaiting += 1 }
          @inflight += 1
          @write_queue.push(bytes)
        end

        def send_all(*messages)
          messages.each { |msg| send_message(msg) }
          flush
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
            # handler owns that shape.
            send_message(@protocol.build_route(routing_context, Array(bookmarks), database, imp_user))
            flush

            # The acquisition timeout must encompass routing discovery, so a
            # router that stalls the ROUTE reply can't outlast it.
            fetch_response(deadline: acquisition_deadline).assert_success!.metadata[:rt]
          rescue Exceptions::Neo4jException
            # ROUTE failure leaves the server in FAILED state — RESET clears it
            # so the connection can be reused.
            reset!
            raise
          end
        end

        # Monotonic deadline from the connection-acquisition timeout, or nil
        # when unconfigured. Bounds discovery reads (ROUTE) the same way the
        # synchronous handshake is bounded.
        def acquisition_deadline
          acq = @options[:connection_acquisition_timeout]&.to_f
          acq && current_monotonic + acq
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

        # No-op: writes are flushed by the writer fiber as it drains the queue.
        # Kept so the established `send_message(...); flush; fetch_response`
        # call shape reads the same — the flush is now implicit and the call
        # sites don't need to change. (A buffered server FAILURE is still
        # observed because the reader drains the socket independently of the
        # writer; fetch_response surfaces it in request order.)
        def flush; end

        # Pop the next response, in request order, blocking until the reader
        # delivers it. The reader pushes a classified exception here when the
        # socket dies, so a broken connection surfaces as a raise rather than a
        # hang (failure fan-out). RECORDs are returned individually, terminating
        # in the request's SUCCESS/FAILURE/IGNORED — same contract as before.
        # `deadline` (monotonic) bounds the wait — used by routing discovery so
        # the connection-acquisition timeout encompasses the ROUTE round-trip
        # too. The reader can't be unparked once it's blocked in a kernel read,
        # but the caller can give up: a timed pop returns nil, which we turn into
        # a dead-connection failure (the slow connection is then discarded, its
        # reader reaped by #close).
        def fetch_response(deadline: nil)
          # Once the socket has died the reader fans its error out as a single
          # queued exception, then stops. Re-raise it for every later call too,
          # so a drain loop (reset!/alive?) that keeps asking doesn't block on a
          # queue nothing will ever fill again.
          raise @dead if @io_mutex.synchronize { @dead } && @responses.empty?

          item = deadline ? @responses.pop(timeout: [deadline - current_monotonic, 0.0].max) : @responses.pop
          raise fail_acquisition_deadline if item.nil? # timed pop elapsed
          raise item if item.is_a?(Exception)

          @inflight -= 1 if item.terminal? && @inflight.positive?
          item
        end

        # Mark the connection dead because an acquisition-phase read (ROUTE)
        # outlasted its deadline, and return the exception to raise. The socket
        # is left for #close to shut down on the reactor thread (closing a fd
        # under the parked reader fiber from here would be cross-thread).
        def fail_acquisition_deadline
          error = Exceptions::ServiceUnavailableException.new(
            "Timed out waiting for a response from #{@address || @uri} within the connection acquisition timeout"
          )
          @io_mutex.synchronize do
            @dead ||= error
            @closed = true
            @dead
          end
        end

        def fetch_all
          results = []
          results << fetch_response while pending_responses?
          results
        end

        # Recover from a FAILED server state. Sends RESET and drains all
        # pending responses (including any IGNOREDs from messages that were
        # queued before the failure). Returns when the server has acknowledged
        # the RESET with SUCCESS and the response queue is empty.
        def reset!
          send_message(Message.reset)
          flush
          fetch_response while pending_responses?
        rescue StandardError
          # If RESET itself fails the connection is likely dead; caller will
          # discover this on next use. Swallow so recovery paths don't mask
          # the original error.
        end

        # True while the caller still owes a fetch for something it sent: a
        # message whose terminal it hasn't consumed (@inflight), or a response
        # the reader has already buffered but the caller hasn't popped. The
        # drain loops in reset!/alive? spin on this.
        def pending_responses?
          @inflight.positive? || !@responses.empty?
        end

        private

        # Start the per-connection reader and writer fibers on the reactor.
        # They take over the socket from here; the caller thread only ever
        # touches it again via teardown_io / close (which run on the reactor).
        def start_io
          @reader_task = @reactor.run { reader_loop }
          @writer_task = @reactor.run { writer_loop }
        end

        # The writer fiber: drain framed message bytes and write them to the
        # socket. One writer keeps wire order; a single reactor thread keeps it
        # off the reader's toes (no concurrent SSL op).
        def writer_loop
          loop do
            bytes = @write_queue.pop
            @socket.write(bytes)
            @socket.flush
          rescue Errno::EPIPE, Errno::ECONNRESET
            # Peer closed mid-write. Don't fail here — the reader drains any
            # buffered server FAILURE first and then surfaces the real broken
            # state on EOF, preserving the error the server actually sent.
          rescue Async::Stop
            break
          rescue IOError, SystemCallError => e
            fail_connection(wrap_wire_error(e))
            break
          end
        end

        # The reader fiber: drain responses for the connection's whole life
        # (including while it sits idle in the pool) and deliver them in request
        # order. A read that exceeds the server's recv-timeout while a reply is
        # outstanding marks the connection broken; the same timeout while idle
        # is just a quiet keepalive and is ignored.
        def reader_loop
          loop do
            @socket.timeout = @io_mutex.synchronize { @recv_timeout }
            deliver(read_one_response)
          rescue IO::TimeoutError
            next unless awaiting?

            fail_connection(Exceptions::ConnectionReadTimeoutException::INSTANCE)
            break
          rescue Async::Stop
            break
          rescue IOError, SystemCallError => e
            fail_connection(wrap_wire_error(e))
            break
          end
        end

        # Read one complete Bolt message (chunk-reassembled) and hydrate it.
        # NOOPs — a bare 00 00 with no chunks — are inline keepalives the server
        # sends to keep a slow response under the recv-timeout; they carry no
        # message, so skip them and keep reading (each read still resets the
        # per-read timeout). Hydration is the only CPU on the reactor — a
        # bounded per-message parse, which the design explicitly allows; records
        # are handed to the caller untouched.
        def read_one_response
          loop do
            message_data = read_message_bytes
            next if message_data.empty? # NOOP keepalive

            unpacker = PackStream::Unpacker.new(StringIO.new(message_data))
            register_hydration_handlers(unpacker)
            return unpacker.unpack
          end
        end

        def read_message_bytes
          message_data = String.new(encoding: Encoding::BINARY)
          loop do
            # During the synchronous handshake, charge each read against the one
            # acquisition deadline (no effect once @read_deadline is cleared and
            # the reader fiber owns the socket timeout).
            @socket.timeout = remaining_handshake_budget if @read_deadline
            chunk_size = @socket.read(2)&.unpack1('S>')
            raise EOFError, 'Unexpected end of stream while reading chunk header' if chunk_size.nil?
            break if chunk_size.zero? # end marker

            chunk = @socket.read(chunk_size)
            raise EOFError, 'Unexpected end of stream while reading chunk body' if chunk.nil? || chunk.bytesize < chunk_size

            message_data << chunk
          end
          message_data
        end

        # Hand a parsed response to the caller. A terminal (SUCCESS/FAILURE/
        # IGNORED) completes one in-flight request, so it drops @awaiting; a
        # RECORD does not. Pushed before the decrement so a drain loop never
        # sees "nothing pending" with the terminal still in flight.
        def deliver(response)
          @responses.push(response)
          @io_mutex.synchronize { @awaiting -= 1 if response.terminal? && @awaiting.positive? }
        end

        # A dead socket / read-timeout resolves every waiting caller: mark the
        # connection dead and fan the classified exception out through the
        # response queue so a blocked (or future) fetch_response raises instead
        # of hanging. Runs in the reader/writer fiber (reactor thread), so it
        # also hangs up the socket right here — the peer must see the
        # disconnect promptly (e.g. the recv-timeout liveness contract asserts
        # the driver hangs up a timed-out connection). The sibling fiber is
        # reaped later by #close when the pool discards this connection.
        def fail_connection(error)
          @io_mutex.synchronize do
            return if @dead

            @dead = error
            @closed = true
          end
          @responses.push(error)
          @socket&.close rescue nil
        end

        # Stop the reader/writer and close the socket on the reactor thread that
        # owns them. Safe to call before start_io (no fibers yet) and idempotent.
        def teardown_io
          reader = @reader_task
          writer = @writer_task
          socket = @socket

          if reader || writer
            @reactor.run_and_wait do
              reader&.stop
              writer&.stop
              socket&.close
            end
          else
            socket&.close rescue nil
          end
        rescue StandardError
          socket&.close rescue nil
        ensure
          @socket = nil
          @reader_task = nil
          @writer_task = nil
        end

        def awaiting? = @io_mutex.synchronize { @awaiting.positive? }

        def mark_closed = @io_mutex.synchronize { @closed = true }

        # Pack a message and wrap it in Bolt chunk framing (one or more
        # size-prefixed chunks + the 0x00 0x00 end marker) as a single byte
        # string for the writer.
        def framed_message(message)
          @packer.reset
          @packer.pack_message(message)
          data = @packer.bytes

          buffer = String.new(encoding: Encoding::BINARY)
          offset = 0
          while offset < data.bytesize
            chunk_size = [data.bytesize - offset, 65535].min
            buffer << [chunk_size].pack('S>')
            buffer << data.byteslice(offset, chunk_size)
            offset += chunk_size
          end
          buffer << [0x00, 0x00].pack('S>')
        end

        # Convert a transport-level failure (broken socket, EOF on a partial
        # read, etc.) into a ServiceUnavailableException so callers see a
        # uniform Neo4jException — same shape as a clean disconnect during
        # connect(). An already-classified Neo4jException passes through.
        def wrap_wire_error(error)
          return error if error.is_a?(Exceptions::Neo4jException)

          Exceptions::ServiceUnavailableException.new(
            "Connection to #{@address || @uri} broken: #{error.class}: #{error.message}"
          )
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
          tcp_socket = timeout ? Socket.tcp(bare_host, port, connect_timeout: timeout) : TCPSocket.new(bare_host, port)
        rescue SystemCallError, SocketError => e
          raise Exceptions::ServiceUnavailableException,
                "Unable to connect to #{format_address(host, port)}, ensure the database is running and that there is a working network connection to it. (#{e.message})"
        else
          @address = format_address(host, port)
          tcp_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          @socket = wrap_with_tls(tcp_socket, bare_host, port)
        end

        # Remaining time the synchronous handshake may take before it breaches
        # the acquisition deadline (nil = unbounded). Distinct from
        # `connection_timeout`, which bounds only the TCP connect — a handshake
        # slower than connection_timeout but within the acquisition budget still
        # succeeds. Floored just above zero so a breached deadline still arms a
        # real (immediately-firing) IO#timeout rather than nil (= no timeout).
        def remaining_handshake_budget
          return nil unless @read_deadline

          [@read_deadline - current_monotonic, 0.001].max
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
          agreed_version = Handshake.new(@socket).negotiate
          @server_version = agreed_version
          @bolt_version = BoltVersion.from_int(agreed_version)
          @protocol = ProtocolVersionHandler.for_version(self, agreed_version)
          @protocol.configure_packer(@packer)

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
            routing: @options[:routing_context]
          )

          # Pipeline HELLO and (on 5.1+) LOGON: write both before reading
          # either. A pipelined server replies only once it has the whole
          # handshake (the recv-timeout liveness stub is C: HELLO / C: LOGON /
          # S: SUCCESS / S: SUCCESS), so reading HELLO's reply before sending
          # LOGON would deadlock. This runs synchronously on the caller thread,
          # before start_io — the reader/writer fibers don't exist yet, so the
          # socket is ours to drive directly. On 5.0/4.x build_logon_message is
          # nil (auth went in the HELLO map) — a plain single HELLO round-trip.
          logon_msg = @protocol.build_logon_message(auth_hash)
          @socket.write(framed_message(hello_msg))
          @socket.write(framed_message(logon_msg)) if logon_msg
          @socket.flush

          hello = read_one_response.assert_success!
          @server_agent = hello.metadata[:server]
          # The server may advertise connection.recv_timeout_seconds in HELLO's
          # SUCCESS hints; from start_io on, the reader treats a read that
          # exceeds it (while a reply is outstanding) as a broken connection.
          apply_recv_timeout_hint(hello.metadata[:hints])

          read_one_response.assert_success! if logon_msg
        end

        def apply_recv_timeout_hint(hints)
          seconds = hints && hints[:'connection.recv_timeout_seconds']
          return unless seconds&.positive?

          @io_mutex.synchronize { @recv_timeout = seconds }
        end

        # Both 0x66 (legacy local-seconds) and 0x69 (UTC-seconds, Bolt
        # 5.0+) end up resolving a named tz at a specific instant — the
        # only difference is whether the caller already knows the UTC
        # instant. Keep the zone-DB lookup + offset arithmetic in one
        # place.
        def hydrate_named_zone(instant, zone_name, local_seconds:)
          if defined?(ActiveSupport::TimeZone)
            tz = ActiveSupport::TimeZone[zone_name]
            utc_instant = local_seconds ? tz.tzinfo.local_to_utc(instant) : instant
            tz.at(utc_instant)
          else
            tz = TZInfo::Timezone.get(zone_name)
            utc_instant = local_seconds ? tz.local_to_utc(instant) : instant
            utc_instant.getlocal(tz.period_for_utc(utc_instant).utc_total_offset)
          end
        rescue StandardError
          instant
        end

        def register_hydration_handlers(unpacker)
          # Bolt response messages — top-level structures returned from the server.
          unpacker.register_hydration_handler(Message::SUCCESS) { |fields| Message::Success.new(fields[0] || {}) }
          unpacker.register_hydration_handler(Message::FAILURE) { |fields| Message::Failure.new(fields[0] || {}) }
          unpacker.register_hydration_handler(Message::RECORD)  { |fields| Message::Record.new(fields[0] || []) }
          unpacker.register_hydration_handler(Message::IGNORED) { |_| Message::Ignored.new }

          # Register handlers for Neo4j types (Node, Relationship, etc.)
          # Signature 0x4E - Node
          unpacker.register_hydration_handler(0x4E) do |fields|
            Types::Node.new(fields[0], fields[1].map(&:to_sym), fields[2], fields[3])
          end

          # Signature 0x52 - Relationship (bound).
          # Bolt 5.0+ adds startNodeElementId and endNodeElementId as
          # fields[6] / fields[7]; older protocols omit them and the
          # constructor falls back to nil.
          unpacker.register_hydration_handler(0x52) do |fields|
            Types::Relationship.new(fields[0], fields[1], fields[2], fields[3].to_sym,
                                    fields[4], fields[5], fields[6], fields[7])
          end

          # Signature 0x72 - UnboundRelationship (relationships in paths).
          # Bolt 5.0+ adds elementId as fields[3].
          unpacker.register_hydration_handler(0x72) do |fields|
            Types::UnboundRelationship.new(fields[0], fields[1].to_sym, fields[2], fields[3])
          end

          # Signature 0x50 - Path
          unpacker.register_hydration_handler(0x50) do |fields|
            nodes = fields[0]
            unbound_rels = fields[1]
            indices = fields[2]

            # Build segments from PackStream wire format
            # indices is an array of [rel_idx, node_idx] pairs
            # rel_idx is 1-based, negative means reversed relationship
            segments = []
            bound_rels = []
            current_node = nodes.first

            indices.each_slice(2) do |rel_idx, node_idx|
              next_node = nodes[node_idx]

              # Handle negative indices (relationship traversed in reverse)
              if rel_idx < 0
                unbound_rel = unbound_rels[rel_idx.abs - 1]
                bound_rel = unbound_rel.bind(next_node.id, current_node.id,
                                             next_node.element_id, current_node.element_id)
              else
                unbound_rel = unbound_rels[rel_idx - 1]
                bound_rel = unbound_rel.bind(current_node.id, next_node.id,
                                             current_node.element_id, next_node.element_id)
              end
              segments << Types::Path::Segment.new(current_node, next_node, bound_rel)

              bound_rels << bound_rel
              current_node = next_node
            end

            Types::Path.new(nodes, bound_rels, segments)
          end

          # Add temporal type handlers
          register_temporal_handlers(unpacker)

          # Let the negotiated protocol re-register / add handlers for
          # version-specific message shapes (V5_7 FAILURE, V6_0
          # VECTOR / UNSUPPORTED). Re-registration wins, so this must
          # run last.
          @protocol&.customize_hydration(unpacker)
        end

        def register_temporal_handlers(unpacker)
          # Date - signature 0x44 → Ruby ::Date
          unpacker.register_hydration_handler(0x44) do |fields|
            ::Date.new(1970, 1, 1) + fields[0]
          end

          # OffsetTime - signature 0x54
          unpacker.register_hydration_handler(0x54) do |fields|
            Types::OffsetTime.from_nanos(fields[0], fields[1])
          end

          # LocalTime - signature 0x74
          unpacker.register_hydration_handler(0x74) do |fields|
            Types::LocalTime.from_nanos(fields[0])
          end

          # DateTime with offset - signature 0x46 → Ruby Time
          # (legacy local-seconds encoding, used on Bolt < 4.4 and on
          # Bolt 4.4 without the `[patch_bolt]: utc` patch). Server
          # encodes LOCAL seconds (wall-clock time treated as UTC);
          # subtract the offset to recover the true UTC instant.
          unpacker.register_hydration_handler(0x46) do |fields|
            ::Time.at(fields[0] - fields[2], fields[1], :nanosecond).getlocal(fields[2])
          end

          # DateTime with offset (UTC seconds) - signature 0x49 → Ruby Time.
          # Bolt 5.0+ uses UTC-encoded seconds by default; same payload
          # as 0x46 except `fields[0]` is already the UTC instant, so no
          # offset subtraction.
          unpacker.register_hydration_handler(0x49) do |fields|
            ::Time.at(fields[0], fields[1], :nanosecond).getlocal(fields[2])
          end

          # LocalDateTime - signature 0x64 → Types::LocalDateTime (preserve type for roundtrip)
          unpacker.register_hydration_handler(0x64) do |fields|
            Types::LocalDateTime.from_epoch(fields[0], fields[1])
          end

          # DateTimeZoneId - signature 0x66 (with timezone name) → Ruby Time
          # fields: [local_epoch_seconds, nanoseconds, timezone_name]
          # Legacy LOCAL-seconds encoding. Treat as wall-clock in the
          # target zone and convert to the actual UTC instant (using the
          # zone's offset at that instant so DST is handled both in
          # summer and winter).
          unpacker.register_hydration_handler(0x66) do |fields|
            wall_clock = ::Time.at(fields[0], fields[1], :nanosecond).utc
            hydrate_named_zone(wall_clock, fields[2], local_seconds: true)
          end

          # DateTimeZoneId (UTC seconds) - signature 0x69. Bolt 5.0+
          # encoding. fields[0] is the UTC instant directly; just
          # display it in the named zone.
          unpacker.register_hydration_handler(0x69) do |fields|
            utc_instant = ::Time.at(fields[0], fields[1], :nanosecond).utc
            hydrate_named_zone(utc_instant, fields[2], local_seconds: false)
          end

          # Duration - signature 0x45
          unpacker.register_hydration_handler(0x45) do |fields|
            Types::Duration.new(fields[0], fields[1], fields[2], fields[3])
          end

          # Point2D - signature 0x58
          unpacker.register_hydration_handler(0x58) do |fields|
            Types::Point.new(srid: fields[0], x: fields[1], y: fields[2])
          end

          # Point3D - signature 0x59
          unpacker.register_hydration_handler(0x59) do |fields|
            Types::Point.new(srid: fields[0], x: fields[1], y: fields[2], z: fields[3])
          end
        end
      end
    end
  end
end
