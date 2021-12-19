module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        # Encodes the ROUTE message to the stream
        class RouteV44MessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::RouteMessage)
            packer.pack_struct_header(3, message.signature)
            packer.pack(message.routing_context)
            packer.pack(message.bookmark.present? ? Values.value(message.bookmark.values) : Values.value(java.util.Collections.empty_list))

            if !message.impersonated_user.nil? && message.database_name.nil?
              params = java.util.Collections.singleton_map("imp_user", Values.value(message.impersonated_user))
            elsif !message.database_name.nil?
              params = java.util.Collections.singleton_map("db", Values.value(message.database_name))
            else
              params = java.util.Collections.empty_map
            end

            packer.pack(params)
          end
        end
      end
    end
  end
end
