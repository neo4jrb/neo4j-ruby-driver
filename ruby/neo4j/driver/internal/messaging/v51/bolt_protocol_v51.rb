module Neo4j::Driver
  module Internal
    module Messaging
      module V51
        class BoltProtocolV51 < V5::BoltProtocolV5
          VERSION = BoltProtocolVersion.new(5, 1)
          INSTANCE = new

          def create_message_format
            MessageFormatV51.new
          end

          def initialize_channel(channel, user_agent, auth_token, routing_context)
            message = Request::HelloMessage.new(user_agent, {},
                                                (routing_context.to_h if routing_context.server_routing_enabled?))
            handler = Handlers::HelloV51ResponseHandler.new(channel, VERSION)

            channel.message_dispatcher.enqueue(handler)
            channel.write(message)
            message = Request::LogonMessage(auth_token)
            channel.message_dispatcher.enqueue(LogonResponseHandle.new(channel, auth_token))
            channel.write_and_flush(message)
          end

          def logoff

          end

          def logon

          end

          def version
            self.class::VERSION
          end
        end
      end
    end
  end
end
