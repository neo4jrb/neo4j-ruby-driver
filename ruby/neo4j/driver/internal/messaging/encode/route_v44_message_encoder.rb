module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        # Encodes the ROUTE message to the stream
        class RouteV44MessageEncoder < RouteMessageEncoder
          private

          def option(message)
            if message.impersonated_user && !message.database_name
              { imp_user: message.impersonated_user }
            elsif message.database_name
              { db: message.database_name }
            else
              {}
            end
          end
        end
      end
    end
  end
end
