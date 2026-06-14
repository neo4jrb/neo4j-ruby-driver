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

        def initialize(uri, auth, options = {})
          @uri = URI(uri)
          # The driver's stored auth — the identity HELLO/LOGON
          # authenticated as on connect, and what Session restores via
          # authenticate(driver_auth) when no per-session :auth was
          # given but a previous lessee had switched identity.
          @driver_auth = auth
          @auth = auth
          @options = options
          @socket = nil
          @packer = PackStream::Packer.new
          @response_queue = []
          @server_version = nil
          @bolt_version = nil
          @protocol = nil
          @server_agent = nil
          @closed = false
          @created_at = nil
          @idle_since = nil
          @discard_on_release = false
          @auth_failed = false
        end

        def connect
          last_error = nil
          resolved_addresses.each do |host, port|
            begin
              open_socket(host, port)
              perform_handshake
              perform_hello
              @created_at = current_monotonic
              return self
            rescue Exceptions::AuthenticationException
              # Auth is the same regardless of which address we hit — fail fast.
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
          fetch_response.assert_success! while !@response_queue.empty?
          true
        rescue StandardError
          discard_socket
          @closed = true
          false
        end

        # Monotonic seconds — immune to wall-clock jumps, which is
        # what every age / idle calculation here needs.
        def current_monotonic
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def close
          return if @closed

          begin
            send_message(Message.goodbye) rescue nil
            flush rescue nil
          ensure
            @socket&.close
            @closed = true
          end
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

        # Bolt 5.1+ re-auth: LOGOFF then LOGON with `new_auth`. Used by
        # Session when it has its own `:auth` and the pooled connection
        # is currently authenticated as somebody else. No-op when the
        # connection already holds the target identity.
        def authenticate(new_auth)
          return if @auth == new_auth
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
          # not a token problem: the connection stays usable (so RESET is
          # fine), the auth-token manager is NOT consulted, and the error
          # surfaces unchanged (always retryable) for the managed-tx retry
          # / AuthorizationExpiredTreatment to handle.
          return error if error.is_a?(Exceptions::AuthorizationExpiredException)

          # Other security failures (Unauthorized / TokenExpired) close the
          # connection server-side — skip RESET (the socket is gone). Notify
          # the manager; a retryable verdict surfaces a SecurityRetryable-
          # Exception wrapping the original (code/message preserved, original
          # chained as cause at re-raise).
          @auth_failed = true
          return error unless @security_exception_handler&.call(@auth, error)

          Exceptions::SecurityRetryableException.new(error.message, code: error.code)
        end

        # No-op routing classifier for the direct (bolt://) path — there's
        # no routing table to feed back. Still funnels through the auth
        # manager. Routing::RoutedConnection overrides with the real
        # routing classification (and also notifies). Defined here so
        # session.rb / transaction.rb / Result#on_failure can call
        # `connection.classify_failure(e)` unconditionally.
        def classify_failure(error) = notify_security_exception(error)

        # Defer peer-closed errors from the write path for the same
        # reason as #flush: a server FAILURE buffered before the peer
        # closed should be readable via the subsequent fetch_response.
        # The actually-broken case still surfaces — fetch_response will
        # hit EOF and raise ServiceUnavailableException through
        # with_wire_error_handling. We push :pending unconditionally so
        # the caller's fetch_response always runs.
        def send_message(message)
          raise IOError, 'Connection is closed' if closed?

          begin
            @packer.reset
            @packer.pack_message(message)
            data = @packer.bytes

            # Write chunk header (size as 16-bit big-endian) + data
            write_chunk(data)

            # End marker (0x00 0x00)
            @socket.write([0x00, 0x00].pack('S>'))
          rescue Errno::EPIPE, Errno::ECONNRESET
            # peer-closed — see method comment
          end

          @response_queue << :pending
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

            fetch_response.assert_success!.metadata[:rt]
          rescue Exceptions::Neo4jException
            # ROUTE failure leaves the server in FAILED state — RESET clears it
            # so the connection can be reused.
            reset!
            raise
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
          else
            # 3.0: single-database cluster routing procedure, home db.
            query = 'CALL dbms.cluster.routing.getRoutingTable($context)'
            params = { context: routing_context }
            extra = { mode: 'r' }
          end
          extra[:bookmarks] = Array(bookmarks) unless Array(bookmarks).empty?

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
        def flush
          @socket.flush
        rescue Errno::EPIPE, Errno::ECONNRESET
          # peer-closed — see method comment
        end

        def fetch_response
          with_wire_error_handling do
            # Read all chunks until we hit the end marker (0x00 0x00)
            message_data = String.new(encoding: Encoding::BINARY)

            loop do
              chunk_size = @socket.read(2)&.unpack1('S>')
              # Clean EOF on a half-read header — surface as IOError
              # so the wrapper turns it into a ServiceUnavailable
              # rather than us silently returning a half-decoded
              # response.
              raise IOError, 'Unexpected end of stream while reading chunk header' if chunk_size.nil?
              break if chunk_size.zero? # End marker

              chunk_data = @socket.read(chunk_size)
              # Same as above for the body: nil = peer closed, short
              # bytes = partial read. Either way the message we built
              # would be junk; raise so the wrapper classifies.
              if chunk_data.nil? || chunk_data.bytesize < chunk_size
                raise IOError, 'Unexpected end of stream while reading chunk body'
              end
              message_data << chunk_data
            end

            # Parse the complete message
            io = StringIO.new(message_data)
            unpacker = PackStream::Unpacker.new(io)

            # Register hydration handlers
            register_hydration_handlers(unpacker)

            response = unpacker.unpack

            @response_queue.shift unless @response_queue.empty?
            response
          end
        end

        def fetch_all
          results = []
          while !@response_queue.empty?
            results << fetch_response
          end
          results
        end

        # Recover from a FAILED server state. Sends RESET and drains all
        # pending responses (including any IGNOREDs from messages that were
        # queued before the failure). Returns when the server has acknowledged
        # the RESET with SUCCESS and the response queue is empty.
        def reset!
          send_message(Message.reset)
          flush
          fetch_response while !@response_queue.empty?
        rescue StandardError
          # If RESET itself fails the connection is likely dead; caller will
          # discover this on next use. Swallow so recovery paths don't mask
          # the original error.
        end

        def pending_responses?
          !@response_queue.empty?
        end

        private

        # Convert transport-level failures (broken socket, EOF on a
        # partial read, etc.) into a ServiceUnavailableException so
        # callers see a uniform Neo4jException — same shape as a clean
        # disconnect during connect(). Server-side FAILUREs already
        # raise specific Neo4jException subclasses and propagate
        # untouched; non-IO bugs (ArgumentError from a malformed pack,
        # etc.) also propagate untouched so they don't get misclassified
        # as connection failures.
        def with_wire_error_handling
          yield
        rescue Exceptions::Neo4jException
          raise
        rescue IOError, SystemCallError => e
          raise Exceptions::ServiceUnavailableException,
                "Connection to #{@address || @uri} broken: #{e.class}: #{e.message}"
        end

        def discard_socket
          @socket&.close rescue nil
          @socket = nil
          # If perform_hello pushed a :pending entry before the failure, the
          # next address attempt would otherwise carry it forward and later
          # reset!/drain loops could block waiting for a phantom response.
          @response_queue.clear
        end

        # Resolve the URI's host:port into a list of [host, port] pairs to try
        # in order. Hosts are kept in their native form — IPv6 stays bracketed
        # ("[::1]") so address strings re-parse unambiguously; brackets are
        # only stripped at the TCPSocket boundary.
        # With a custom resolver, the user's callable receives a "host:port"
        # string (IPv6 bracketed) and returns one or more such strings,
        # matching the Java driver's ServerAddressResolver contract.
        def resolved_addresses
          host = @uri.host
          port = @uri.port || DEFAULT_PORT

          if (resolver = @options[:resolver])
            Array(resolver.call(format_address(host, port))).map { |addr| split_addr(addr, port) }
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

          send_message(hello_msg)
          flush

          @server_agent = fetch_response.assert_success!.metadata[:server]

          # On 5.1+ a LOGON follows HELLO (perform_post_hello sends it).
          # On 5.0/4.x this is a no-op because auth went in the HELLO map.
          @protocol.perform_post_hello(auth_hash)
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

        def write_chunk(data)
          # Split data into chunks if necessary (max chunk size 65535)
          offset = 0
          while offset < data.bytesize
            chunk_size = [data.bytesize - offset, 65535].min
            @socket.write([chunk_size].pack('S>'))
            @socket.write(data.byteslice(offset, chunk_size))
            offset += chunk_size
          end
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
