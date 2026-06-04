module Neo4j
  module Driver
    module Ext
      module Internal
        class DriverFactory < org.neo4j.driver.internal.DriverFactory
          def initialize(&domain_name_resolver)
            super()
            return unless domain_name_resolver

            @domain_name_resolver = ->(name) do
              domain_name_resolver.call(name).map do |addr|
                java.net.InetAddress.get_by_name(addr)
              rescue java.net.UnknownHostException => e
                raise java.lang.RuntimeException.new(e)
              end
            end
          end

          # Only divert from Java's default resolver when the caller
          # supplied one; otherwise let `super` return the default.
          def getDomainNameResolver
            @domain_name_resolver || super
          end

          # Override the package-private clock seam. TestkitClock acts
          # as the system clock unless `Internal::Clock.install` has
          # been called, so production behaviour is unchanged.
          def createClock
            TestkitClock::INSTANCE
          end
        end
      end
    end
  end
end
