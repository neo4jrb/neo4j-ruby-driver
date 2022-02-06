module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class NettyDomainNameResolverGroup < org.neo4j.driver.internal.shaded.io.netty.resolver.AddressResolverGroup

          def initialize(domain_name_resolver)
            @domain_name_resolver = domain_name_resolver
          end

          def new_resolver(executor)
            NettyDomainNameResolver.new(executor, @domain_name_resolver).as_address_resolver
          end
        end
      end
    end
  end
end
