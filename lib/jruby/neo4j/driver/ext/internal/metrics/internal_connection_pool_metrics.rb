# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Metrics
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
