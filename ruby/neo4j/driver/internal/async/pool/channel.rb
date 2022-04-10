module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class Channel < ::Async::Pool::Resource
          attr :stream
          attr_accessor :version, :protocol, :message_format, :message_dispatcher
          attr :attributes # should be attr

          def initialize(address, connector, connection_acquisition_timeout, logger)
            super()
            @attributes = Connection::ChannelAttributes.new
            @stream = Connection::Stream.new(connector.connect(address))
            @stream.write(Connection::BoltProtocolUtil.handshake_buf)
            @stream.flush
            Connection::HandshakeHandler.new(logger).decode(self)
            stream_reader = Connection::StreamReader.new(@stream)
            stream_writer = Outbound::ChunkAwareByteBufOutput.new(@stream)
            @message_dispatcher = Inbound::InboundMessageDispatcher.new(self, logger)
            @attributes[:message_dispatcher] = @message_dispatcher
            @outbound_handler = Outbound::OutboundMessageHandler.new(stream_writer, message_format, logger)
            connector.initialize_channel(self, protocol)
            # @message_dispatcher.enqueue(Handlers::HelloResponseHandler.new(self, attributes[:protocol_version]))
            common_message_reader = Messaging::Common::CommonMessageReader.new(stream_reader)
            common_message_reader.read(@message_dispatcher)
            Async do
              loop do
                common_message_reader.read(@message_dispatcher)
              end
            end
          end

          def close
            super unless closed? # Should this be conditional?
            @stream.close
          end

          def write(message)
            @outbound_handler.encode(message)
          end

          def write_and_flush(message)
            write(message)
            @stream.flush
          end

          private

          def bracketless(host)
            host.delete_prefix('[').delete_suffix(']')
          end
        end
      end
    end
  end
end
