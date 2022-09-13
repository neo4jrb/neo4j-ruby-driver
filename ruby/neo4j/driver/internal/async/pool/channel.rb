module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class Channel
          attr :stream
          attr_accessor :version, :protocol, :message_format, :message_dispatcher
          attr :attributes # should be attr
          attr_accessor :auto_read

          def initialize(address, connector, logger)
            @closed = false
            @attributes = Connection::ChannelAttributes.new
            @stream = Connection::Stream.new(connect_to_io_socket(connector, address))
            @stream.write(Connection::BoltProtocolUtil.handshake_buf)
            @stream.flush
            Connection::HandshakeHandler.new(logger).decode(self)
            stream_reader = Connection::StreamReader.new(@stream)
            stream_writer = Outbound::ChunkAwareByteBufOutput.new(@stream)
            @message_dispatcher = Inbound::InboundMessageDispatcher.new(self, logger)
            @attributes[:message_dispatcher] = @message_dispatcher
            @outbound_handler = Outbound::OutboundMessageHandler.new(stream_writer, message_format, logger)
            @common_message_reader = Messaging::Common::CommonMessageReader.new(stream_reader)
            connector.initialize_channel(self, protocol)
          end

          def close
            @closed = true
            @stream.close
          end

          def write(message)
            @outbound_handler.encode(message)
          end

          def write_and_flush(message)
            write(message)
            @stream.flush
            ensure_response_handling
          end

          private

          def connect_to_io_socket(connector, address)
            Sync { connector.connect(address) }
          end

          def bracketless(host)
            host.delete_prefix('[').delete_suffix(']')
          end

          def ensure_response_handling
            # probably should be synchronized
            return if @handling_active
            @handling_active = true
            while @message_dispatcher.queued_handlers_count > 0 do
              @common_message_reader.read(@message_dispatcher)
            end
            @handling_active = false
          rescue
            @handling_active = false
            raise
          end
        end
      end
    end
  end
end
