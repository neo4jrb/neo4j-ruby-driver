# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalSummaryCounters < Hash
          def initialize(stats)
            super(0)
            stats&.each { |key, value| self[key.to_s.split('-').join('_').to_sym] = value }
          end

          def method_missing(method)
            self[method]
          end
        end
      end
    end
  end
end
