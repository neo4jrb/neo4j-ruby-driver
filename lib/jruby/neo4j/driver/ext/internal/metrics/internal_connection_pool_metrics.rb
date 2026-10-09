# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Metrics
          # Reads the protected getAddress off the Java connection-pool-metrics
          # object via reflection, exposing it as the pool's address.
          module InternalConnectionPoolMetrics
            def address
              java_class.declared_method('getAddress').tap { |m| m.accessible = true }.invoke(java_object)
            end
          end
        end
      end
    end
  end
end
