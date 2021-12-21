module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class RouteMessage
          SIGNATURE = 0x66

          attr_reader :routing_context, :bookmark, :database_name, :impersonated_user

          # Constructor

          # @param routingContext   The routing context used to define the routing table. Multi-datacenter deployments is one of its use cases.
          # @param bookmark         The bookmark used when getting the routing table.
          # @param databaseName     The name of the database to get the routing table for.
          # @param impersonatedUser The name of the impersonated user to get the routing table for, should be {@code null} for non-impersonated requests
          def initialize(routing_context, bookmark, database_name, impersonated_user)
            @routing_context = java.util.Collections.unmodifiable_map(routing_context)
            @bookmark = bookmark
            @database_name = database
            @impersonated_user = impersonated_user
          end

          def to_s
            "ROUTE #{routing_context}, #{bookmark}, #{database_name} #{impersonated_user}"
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            routing_context.equals(object.routing_context) &&
            java.util.Objects.equals(database_name, object.database_name) &&
            java.util.Objects.equals(impersonated_user, object.impersonated_user)
          end

          def hash_code
            java.util.Objects.hash(routing_context, database_name, impersonated_user)
          end
        end
      end
    end
  end
end
