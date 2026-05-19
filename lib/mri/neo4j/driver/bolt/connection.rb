# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Handles a single Bolt protocol connection over TCP
      class Connection
        MAGIC_PREAMBLE = "\x60\x60\xB0\x17".b
        DEFAULT_PORT = 7687

        # Bolt protocol versions. Wire format is a 4-byte big-endian:
        # [reserved=0, range=0, minor, major]. So version 5.7 packs as
        # 0x00_00_07_05 (minor=7, major=5). Don't be fooled by 4.4 — that
        # one is a palindrome.
        BOLT_VERSION_6_0 = 0x00_00_00_06
        BOLT_VERSION_5_7 = 0x00_00_07_05
        BOLT_VERSION_5_6 = 0x00_00_06_05
        BOLT_VERSION_5_5 = 0x00_00_05_05
        BOLT_VERSION_5_4 = 0x00_00_04_05
        BOLT_VERSION_5_3 = 0x00_00_03_05
        BOLT_VERSION_5_2 = 0x00_00_02_05
        BOLT_VERSION_5_1 = 0x00_00_01_05
        BOLT_VERSION_5_0 = 0x00_00_00_05
        BOLT_VERSION_4_4 = 0x00_00_04_04
        BOLT_VERSION_4_3 = 0x00_00_03_04
        BOLT_VERSION_4_2 = 0x00_00_02_04

        attr_reader :server_version, :server_agent, :protocol, :address

        def initialize(uri, auth, options = {})
          @uri = URI(uri)
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
        end

        def connect
          last_error = nil
          resolved_addresses.each do |host, port|
            begin
              open_socket(host, port)
              perform_handshake
              perform_hello
              return self
            rescue Exceptions::AuthenticationException
              # Auth is the same regardless of which address we hit — fail fast.
              raise
            rescue Exceptions::ServiceUnavailableException, IOError, SystemCallError => e
              last_error = e
              discard_socket
            end
          end

          raise last_error || Exceptions::ServiceUnavailableException.new('No addresses to connect to')
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

        # No-op classifier for the direct (bolt://) path — there's no
        # routing table to feed back, no `on_write_failure`, no
        # write-failure-to-SessionExpired swap. Routing::RoutedConnection
        # overrides this with the real implementation. Defined here so
        # session.rb / transaction.rb / Result#on_failure can call
        # `connection.classify_failure(e)` unconditionally without
        # `respond_to?` guards.
        def classify_failure(error) = error

        def send_message(message)
          with_wire_error_handling do
            raise IOError, 'Connection is closed' if closed?

            @packer.reset
            @packer.pack_message(message)
            data = @packer.bytes

            # Write chunk header (size as 16-bit big-endian) + data
            write_chunk(data)

            # End marker (0x00 0x00)
            @socket.write([0x00, 0x00].pack('S>'))

            @response_queue << :pending
          end
        end

        def send_all(*messages)
          messages.each { |msg| send_message(msg) }
          flush
        end

        # Bolt 4.3+ ROUTE call. Returns the routing-table map from the
        # SUCCESS response (the `rt` field). Caller wraps it in
        # Routing::RoutingTable.from_response.
        def route(database: nil, bookmarks: [], imp_user: nil, routing_context: {})
          extra = { db: database, imp_user: imp_user }.compact
          send_message(Message.route(routing_context, bookmarks, extra))
          flush

          fetch_response.assert_success!.metadata[:rt]
        rescue Exceptions::Neo4jException
          # ROUTE failure leaves the server in FAILED state — RESET clears it
          # so the connection can be reused.
          reset!
          raise
        end

        def flush
          with_wire_error_handling { @socket.flush }
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
          @socket = timeout ? Socket.tcp(bare_host, port, connect_timeout: timeout) : TCPSocket.new(bare_host, port)
        rescue SystemCallError, SocketError => e
          raise Exceptions::ServiceUnavailableException,
                "Unable to connect to #{format_address(host, port)}, ensure the database is running and that there is a working network connection to it. (#{e.message})"
        else
          @address = format_address(host, port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

          if timeout
            timeval = [timeout, 0].pack('l_2')
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, timeval)
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, timeval)
          end
        end

        def perform_handshake
          # Send magic preamble
          @socket.write(MAGIC_PREAMBLE)

          # Handshake v1 sends exactly 4 version proposals, highest priority
          # first; unused slots are zero. We propose the 4.x family — our
          # Protocol::V4 handler covers all of them since the message
          # format only diverged from 4.0 in additive ways (4.3 added
          # ROUTE, 4.4 added imp_user/hints — we don't send those to
          # servers that didn't negotiate the version anyway).
          # 5.x needs a `bolt_agent` map and 5.1+ moves auth to a separate
          # LOGON message — tracked separately.
          proposals = [BOLT_VERSION_4_4, BOLT_VERSION_4_3, BOLT_VERSION_4_2, 0]
          proposals.each { |v| @socket.write([v].pack('L>')) }

          @socket.flush

          # Read agreed version
          version_bytes = @socket.read(4)
          if version_bytes.nil? || version_bytes.bytesize < 4
            raise Exceptions::ServiceUnavailableException, 'Server closed the connection during handshake'
          end

          agreed_version = version_bytes.unpack1('L>')
          if agreed_version.zero?
            raise Exceptions::ServiceUnavailableException, 'Server does not support any of the proposed Bolt versions'
          end

          @server_version = agreed_version
          @bolt_version = BoltVersion.from_int(agreed_version)

          # Create version-specific protocol handler
          @protocol = ProtocolVersionHandler.for_version(self, agreed_version)

          # Debug logging
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
          # driver options).
          hello_msg = @protocol.build_hello_message(
            user_agent: @options[:user_agent] || "neo4j-ruby-driver/#{Neo4j::Driver::VERSION}",
            auth: auth_hash,
            routing: @options[:routing_context]
          )

          send_message(hello_msg)
          flush

          @server_agent = fetch_response.assert_success!.metadata[:server]
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
          # Server encodes LOCAL seconds (wall-clock time treated as UTC);
          # subtract the offset to recover the true UTC instant before
          # displaying in the given offset.
          unpacker.register_hydration_handler(0x46) do |fields|
            ::Time.at(fields[0] - fields[2], fields[1], :nanosecond).getlocal(fields[2])
          end

          # LocalDateTime - signature 0x64 → Types::LocalDateTime (preserve type for roundtrip)
          unpacker.register_hydration_handler(0x64) do |fields|
            Types::LocalDateTime.from_epoch(fields[0], fields[1])
          end

          # DateTimeZoneId - signature 0x66 (with timezone name) → Ruby Time
          # fields: [local_epoch_seconds, nanoseconds, timezone_name]
          # Server encodes LOCAL seconds (wall-clock time treated as UTC), so
          # we treat those seconds as a wall-clock in the target zone and
          # convert to the actual UTC instant — using the zone's offset at
          # that instant so DST is handled correctly in both summer and winter.
          unpacker.register_hydration_handler(0x66) do |fields|
            wall_clock = ::Time.at(fields[0], fields[1], :nanosecond).utc
            begin
              if defined?(ActiveSupport::TimeZone)
                tz = ActiveSupport::TimeZone[fields[2]]
                utc_instant = tz.tzinfo.local_to_utc(wall_clock)
                tz.at(utc_instant)
              else
                tz = TZInfo::Timezone.get(fields[2])
                utc_instant = tz.local_to_utc(wall_clock)
                utc_instant.getlocal(tz.period_for_utc(utc_instant).utc_total_offset)
              end
            rescue StandardError
              wall_clock
            end
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
