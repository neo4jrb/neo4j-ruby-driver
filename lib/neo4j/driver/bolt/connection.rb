# frozen_string_literal: true

require 'socket'
require 'uri'
require 'stringio'

module Neo4j
  module Driver
    module Bolt
      # Handles a single Bolt protocol connection over TCP
      class Connection
        MAGIC_PREAMBLE = "\x60\x60\xB0\x17".b
        DEFAULT_PORT = 7687

        # Bolt protocol versions
        BOLT_VERSION_6_0 = 0x00_00_06_00
        BOLT_VERSION_5_7 = 0x00_00_05_07
        BOLT_VERSION_5_6 = 0x00_00_05_06
        BOLT_VERSION_5_5 = 0x00_00_05_05
        BOLT_VERSION_5_4 = 0x00_00_05_04
        BOLT_VERSION_5_3 = 0x00_00_05_03
        BOLT_VERSION_5_2 = 0x00_00_05_02
        BOLT_VERSION_5_1 = 0x00_00_05_01
        BOLT_VERSION_5_0 = 0x00_00_05_00
        BOLT_VERSION_4_4 = 0x00_00_04_04

        attr_reader :server_version, :server_agent, :protocol

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
          host = @uri.host
          # Strip brackets from IPv6 addresses (URI returns [::1], but TCPSocket expects ::1)
          host = host[1..-2] if host&.start_with?('[') && host.end_with?(']')
          port = @uri.port || DEFAULT_PORT

          @socket = TCPSocket.new(host, port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

          # Set socket timeout if specified
          if (timeout = @options[:connection_timeout])
            timeval = [timeout, 0].pack('l_2')
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, timeval)
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, timeval)
          end

          perform_handshake
          perform_hello

          self
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

        def send_message(message)
          raise IOError, "Connection is closed" if closed?

          @packer.reset
          @packer.pack(message)
          data = @packer.bytes

          # Write chunk header (size as 16-bit big-endian) + data
          write_chunk(data)

          # End marker (0x00 0x00)
          @socket.write([0x00, 0x00].pack('S>'))

          @response_queue << :pending
        end

        def send_all(*messages)
          messages.each { |msg| send_message(msg) }
          flush
        end

        def flush
          @socket.flush
        end

        def fetch_response
          # Read all chunks until we hit the end marker (0x00 0x00)
          message_data = String.new(encoding: Encoding::BINARY)

          loop do
            chunk_size = @socket.read(2)&.unpack1('S>')
            break if chunk_size.nil? || chunk_size.zero? # End marker

            chunk_data = @socket.read(chunk_size)
            message_data << chunk_data
          end

          # Parse the complete message
          io = StringIO.new(message_data)
          unpacker = PackStream::Unpacker.new(io)

          # Register hydration handlers
          register_hydration_handlers(unpacker)

          structure = unpacker.unpack

          @response_queue.shift unless @response_queue.empty?
          process_response(structure)
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

        def perform_handshake
          # Send magic preamble
          @socket.write(MAGIC_PREAMBLE)

          # Send version proposals (4 versions, highest priority first)
          versions = [
            BOLT_VERSION_6_0,
            BOLT_VERSION_5_7,
            BOLT_VERSION_5_4,
            BOLT_VERSION_4_4
          ]

          versions.each do |version|
            @socket.write([version].pack('L>'))
          end

          @socket.flush

          # Read agreed version
          agreed_version = @socket.read(4).unpack1('L>')

          if agreed_version.zero?
            raise "Server does not support any of the proposed Bolt versions"
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

          # Use protocol handler to build version-specific HELLO message
          hello_msg = @protocol.build_hello_message(
            user_agent: "neo4j-ruby-driver2/0.1.0",
            auth: auth_hash
          )

          send_message(hello_msg)
          flush

          response = fetch_response

          if response.is_a?(Message::Success)
            @server_agent = response.metadata[:server]
          elsif response.is_a?(Message::Failure)
            raise "Authentication failed: #{response.message}"
          else
            raise "Unexpected response to HELLO: #{response.class}"
          end
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


        def process_response(structure)
          case structure.signature
          when Message::SUCCESS
            Message::Success.new(structure.fields[0] || {})
          when Message::RECORD
            Message::Record.new(structure.fields[0] || [])
          when Message::FAILURE
            Message::Failure.new(structure.fields[0] || {})
          when Message::IGNORED
            Message::Ignored.new
          else
            raise "Unknown response signature: 0x#{structure.signature.to_s(16)}"
          end
        end

        def register_hydration_handlers(unpacker)
          # Register handlers for Neo4j types (Node, Relationship, etc.)
          # Signature 0x4E - Node
          unpacker.register_hydration_handler(0x4E) do |fields|
            Types::Node.new(fields[0], fields[1].map(&:to_sym), fields[2], fields[3])
          end

          # Signature 0x52 - Relationship (bound)
          unpacker.register_hydration_handler(0x52) do |fields|
            Types::Relationship.new(fields[0], fields[1], fields[2], fields[3].to_sym, fields[4], fields[5])
          end

          # Signature 0x72 - UnboundRelationship (relationships in paths)
          unpacker.register_hydration_handler(0x72) do |fields|
            Types::UnboundRelationship.new(fields[0], fields[1].to_sym, fields[2])
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
                bound_rel = unbound_rel.bind(next_node.id, current_node.id)
                segments << Types::Path::Segment.new(current_node, next_node, bound_rel)
              else
                unbound_rel = unbound_rels[rel_idx - 1]
                bound_rel = unbound_rel.bind(current_node.id, next_node.id)
                segments << Types::Path::Segment.new(current_node, next_node, bound_rel)
              end

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

          # Time - signature 0x54
          unpacker.register_hydration_handler(0x54) do |fields|
            Types::Time.from_nanos(fields[0], fields[1])
          end

          # LocalTime - signature 0x74
          unpacker.register_hydration_handler(0x74) do |fields|
            Types::LocalTime.from_nanos(fields[0])
          end

          # DateTime - signature 0x46 (with timezone) → Ruby Time
          unpacker.register_hydration_handler(0x46) do |fields|
            ::Time.at(fields[0], fields[1], :nanosecond).getlocal(fields[2])
          end

          # LocalDateTime - signature 0x64 → Types::LocalDateTime (preserve type for roundtrip)
          unpacker.register_hydration_handler(0x64) do |fields|
            Types::LocalDateTime.from_epoch(fields[0], fields[1])
          end

          # DateTimeZoneId - signature 0x66 (with timezone name) → Ruby Time
          unpacker.register_hydration_handler(0x66) do |fields|
            # fields: [epoch_seconds, nanoseconds, timezone_name]
            # Neo4j sends epoch seconds for the LOCAL time value, need to adjust to get UTC
            begin
              if defined?(ActiveSupport::TimeZone)
                # Use ActiveSupport::TimeZone which handles timezone conversion
                tz = ActiveSupport::TimeZone[fields[2]]
                # Subtract the timezone offset to get the correct UTC time
                time_with_nanos = fields[0] + fields[1] / 1_000_000_000.0
                tz.at(time_with_nanos - 2 * tz.utc_offset)
              else
                # Fall back to creating UTC time and converting
                utc_time = ::Time.at(fields[0], fields[1], :nanosecond, in: "UTC")
                require 'tzinfo' unless defined?(TZInfo)
                tz = TZInfo::Timezone.get(fields[2])
                period = tz.period_for_utc(utc_time)
                utc_time.getlocal(period.offset.utc_total_offset)
              end
            rescue StandardError => e
              # If timezone conversion fails, return UTC time
              ::Time.at(fields[0], fields[1], :nanosecond, in: "UTC")
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
