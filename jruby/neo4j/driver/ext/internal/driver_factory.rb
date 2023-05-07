module Neo4j
  module Driver
    module Ext
      module Internal
        class DriverFactory < org.neo4j.driver.internal.DriverFactory
          def initialize(&domain_name_resolver)
            super()
            @domain_name_resolver = ->(name) do
              domain_name_resolver.call(name).map do |addr|
                java.net.InetAddress.get_by_name(addr)
              rescue java.net.UnknownHostException => e
                raise java.lang.RuntimeException.new(e)
              end
            end
          end

          def getDomainNameResolver
            @domain_name_resolver
          end
        end
      end
    end
  end
end
