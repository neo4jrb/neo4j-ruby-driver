module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        # From the application point of view it is not interesting to know about the role a member plays in the cluster. Instead, the application needs to know which
        # instance can provide the wanted service.
        # <p>
        # This message is used to fetch this routing information.
        #
        # @param routingContext   The routing context used to define the routing table. Multi-datacenter deployments is one of its use cases.
        # @param bookmark         The bookmark used when getting the routing table.
        # @param databaseName     The name of the database to get the routing table for.
        # @param impersonatedUser The name of the impersonated user to get the routing table for, should be {@code null} for non-impersonated requests
        class RouteMessage < Struct.new(:routing_context, :bookmark, :database_name, :impersonated_user)
          SIGNATURE = 0x66

          def signature
            SIGNATURE
          end

          def to_s
            "ROUTE #{values.join(' ')}"
          end
        end
      end
    end
  end
end
