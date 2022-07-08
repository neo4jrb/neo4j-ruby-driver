module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        # Encodes the ROUTE message to the stream
        class RouteMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::RouteMessage)
            packer.pack_struct_header(3, message.signature)
            packer.pack(message.routing_context)
            packer.pack(message.bookmark&.values || [])
            packer.pack(option(message))
          end

          private

          def option(message)
            message.database_name
          end
        end
      end
    end
  end
end
