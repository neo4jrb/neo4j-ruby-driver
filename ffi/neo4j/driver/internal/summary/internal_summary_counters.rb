# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalSummaryCounters
          def initialize(stats)
            @stats = stats || RecursiveOpenStruct.new
          end

          def contains_updates?
            @stats.to_h.values.any?(&:positive?)
          end

          def method_missing(method)
            @stats.send(method) || 0
          end
        end
      end
    end
  end
end
