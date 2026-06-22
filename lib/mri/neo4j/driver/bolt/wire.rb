# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Sans-I/O Bolt protocol core: a pure state machine with **no socket**.
      #
      #   * `enqueue(message)` packs + chunk-frames a request into an outbound
      #     byte buffer; `take_outbound` hands those bytes to whoever owns the
      #     socket.
      #   * `receive(bytes)` feeds inbound bytes and returns the complete
      #     messages now decodable (Success / Failure / Record / Ignored), in
      #     order — reassembling chunks across calls, skipping NOOP keepalives,
      #     and retaining any trailing partial bytes for the next call.
      #
      # Because it never touches a socket, the whole Bolt framing + hydration
      # path is unit-testable without a network, and stays identical regardless
      # of how I/O is driven (blocking thread, fiber pump, on-demand). See
      # docs/sans-io-pump.md.
      #
      # Created after the handshake — it needs the negotiated protocol to
      # configure the packer (UTC datetime flag) and to customise hydration for
      # version-specific message shapes.
      class Wire
        # Bolt message chunking: a message is a sequence of `[u16 size][size
        # bytes]` chunks terminated by a zero-size chunk (the 0x00 0x00 end
        # marker). A bare end marker with no preceding chunks is a NOOP — an
        # inline keepalive the server sends to keep a slow response under the
        # recv-timeout; it carries no message.
        END_MARKER = "\x00\x00".b
        MAX_CHUNK = 65_535

        def initialize(protocol)
          @protocol = protocol
          @packer = PackStream::Packer.new
          @protocol.configure_packer(@packer)
          @outbound = binary_string
          @inbound = binary_string   # received bytes not yet parsed into messages
          @message = binary_string   # chunks of the in-progress inbound message
          # Response-ordering FIFO. Bolt replies in request order, so each sent
          # request pushes the handler that will receive its response(s); the
          # front handler always owns the next reply. A handler is any response
          # visitor (responds to on_record/on_success/on_failure/on_ignored —
          # the same interface Message#accept dispatches to).
          @handlers = []
        end

        # Pack + chunk-frame `message` into the outbound buffer and register the
        # handler for its reply. Several enqueues before a take_outbound are
        # exactly the pipelining Bolt expects (HELLO+LOGON, RUN+PULL); the FIFO
        # keeps each request matched to its response.
        def enqueue(message, handler)
          @packer.reset
          @packer.pack_message(message)
          data = @packer.bytes

          offset = 0
          while offset < data.bytesize
            size = [data.bytesize - offset, MAX_CHUNK].min
            @outbound << [size].pack('S>') << data.byteslice(offset, size)
            offset += size
          end
          @outbound << END_MARKER
          @handlers.push(handler)
          self
        end

        def pending_outbound? = !@outbound.empty?

        # Requests still awaiting their terminal reply.
        def in_flight = @handlers.size

        # Hand over (and clear) the framed bytes to write to the socket.
        def take_outbound
          out = @outbound
          @outbound = binary_string
          out
        end

        # Feed inbound bytes and route each fully-decoded message to the front
        # handler (via its own #accept visitor). A RECORD keeps the handler at
        # the front (one request streams many); a terminal (SUCCESS/FAILURE/
        # IGNORED) completes the request and pops it. NOOP keepalives carry no
        # message and are skipped. Partial bytes are retained for the next call.
        def receive(bytes)
          @inbound << bytes
          while (message = next_message)
            next if message == :noop || @handlers.empty?

            message.accept(@handlers.first)
            @handlers.shift if message.terminal?
          end
        end

        private

        # Pull one complete message off the front of @inbound, or nil if more
        # bytes are needed. Reassembles all of a message's chunks; returns
        # :noop for a bare end marker. Consumes only what it fully parses.
        def next_message
          consumed = 0
          loop do
            return retain(consumed) if @inbound.bytesize - consumed < 2

            size = @inbound.byteslice(consumed, 2).unpack1('S>')
            consumed += 2

            if size.zero? # end marker
              if @message.empty?
                advance(consumed)
                return :noop
              end
              advance(consumed)
              return unpack(take_message)
            end

            return retain(consumed - 2) if @inbound.bytesize - consumed < size

            @message << @inbound.byteslice(consumed, size)
            consumed += size
          end
        end

        # Not enough bytes for the next chunk: drop what we've consumed so far
        # (its chunks are already accumulated in @message) and signal "need
        # more" with nil.
        def retain(consumed)
          advance(consumed)
          nil
        end

        def advance(consumed)
          return if consumed.zero?

          @inbound = @inbound.byteslice(consumed..) || binary_string
        end

        def take_message
          data = @message
          @message = binary_string
          data
        end

        def unpack(data)
          unpacker = PackStream::Unpacker.new(StringIO.new(data))
          register_hydration_handlers(unpacker)
          unpacker.unpack
        end

        def binary_string = String.new(encoding: Encoding::BINARY)

        # --- Hydration (owned by the core; identical to the legacy path) -----

        def register_hydration_handlers(unpacker)
          unpacker.register_hydration_handler(Message::SUCCESS) { |fields| Message::Success.new(fields[0] || {}) }
          unpacker.register_hydration_handler(Message::FAILURE) { |fields| Message::Failure.new(fields[0] || {}) }
          unpacker.register_hydration_handler(Message::RECORD)  { |fields| Message::Record.new(fields[0] || []) }
          unpacker.register_hydration_handler(Message::IGNORED) { |_| Message::Ignored.new }

          # Signature 0x4E - Node
          unpacker.register_hydration_handler(0x4E) do |fields|
            Types::Node.new(fields[0], fields[1].map(&:to_sym), fields[2], fields[3])
          end

          # Signature 0x52 - Relationship (bound). Bolt 5.0+ adds
          # startNodeElementId/endNodeElementId as fields[6]/fields[7].
          unpacker.register_hydration_handler(0x52) do |fields|
            Types::Relationship.new(fields[0], fields[1], fields[2], fields[3].to_sym,
                                    fields[4], fields[5], fields[6], fields[7])
          end

          # Signature 0x72 - UnboundRelationship. Bolt 5.0+ adds elementId.
          unpacker.register_hydration_handler(0x72) do |fields|
            Types::UnboundRelationship.new(fields[0], fields[1].to_sym, fields[2], fields[3])
          end

          # Signature 0x50 - Path
          unpacker.register_hydration_handler(0x50) do |fields|
            nodes = fields[0]
            unbound_rels = fields[1]
            indices = fields[2]

            segments = []
            bound_rels = []
            current_node = nodes.first

            indices.each_slice(2) do |rel_idx, node_idx|
              next_node = nodes[node_idx]

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

          register_temporal_handlers(unpacker)

          # Version-specific re-registration (V5_7 FAILURE, V6_0 VECTOR /
          # UNSUPPORTED) wins, so it runs last.
          @protocol&.customize_hydration(unpacker)
        end

        def register_temporal_handlers(unpacker)
          # Date (0x44) → ::Date
          unpacker.register_hydration_handler(0x44) { |fields| ::Date.new(1970, 1, 1) + fields[0] }
          # OffsetTime (0x54)
          unpacker.register_hydration_handler(0x54) { |fields| Types::OffsetTime.from_nanos(fields[0], fields[1]) }
          # LocalTime (0x74)
          unpacker.register_hydration_handler(0x74) { |fields| Types::LocalTime.from_nanos(fields[0]) }
          # DateTime with offset, legacy LOCAL seconds (0x46): subtract offset.
          unpacker.register_hydration_handler(0x46) do |fields|
            ::Time.at(fields[0] - fields[2], fields[1], :nanosecond).getlocal(fields[2])
          end
          # DateTime with offset, UTC seconds (0x49, Bolt 5.0+).
          unpacker.register_hydration_handler(0x49) do |fields|
            ::Time.at(fields[0], fields[1], :nanosecond).getlocal(fields[2])
          end
          # LocalDateTime (0x64)
          unpacker.register_hydration_handler(0x64) { |fields| Types::LocalDateTime.from_epoch(fields[0], fields[1]) }
          # DateTimeZoneId, legacy LOCAL seconds (0x66).
          unpacker.register_hydration_handler(0x66) do |fields|
            wall_clock = ::Time.at(fields[0], fields[1], :nanosecond).utc
            hydrate_named_zone(wall_clock, fields[2], local_seconds: true)
          end
          # DateTimeZoneId, UTC seconds (0x69, Bolt 5.0+).
          unpacker.register_hydration_handler(0x69) do |fields|
            utc_instant = ::Time.at(fields[0], fields[1], :nanosecond).utc
            hydrate_named_zone(utc_instant, fields[2], local_seconds: false)
          end
          # Duration (0x45)
          unpacker.register_hydration_handler(0x45) { |fields| Types::Duration.new(fields[0], fields[1], fields[2], fields[3]) }
          # Point2D (0x58)
          unpacker.register_hydration_handler(0x58) { |fields| Types::Point.new(srid: fields[0], x: fields[1], y: fields[2]) }
          # Point3D (0x59)
          unpacker.register_hydration_handler(0x59) do |fields|
            Types::Point.new(srid: fields[0], x: fields[1], y: fields[2], z: fields[3])
          end
        end

        # See CLAUDE.md "LOCAL seconds encoding". Both 0x66 (legacy local) and
        # 0x69 (UTC) resolve a named tz at an instant; the only difference is
        # whether the caller already has the UTC instant.
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
      end
    end
  end
end
