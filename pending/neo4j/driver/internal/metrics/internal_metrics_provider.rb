module Neo4j::Driver
  module Internal
    module Metrics
      class InternalMetricsProvider
        attr_reader :metrics
        alias metrics_listener metrics

        def initialize(logger)
          @metrics = InternalMetrics.new(logger)
        end

        def metrics_enabled?
          true
        end
      end
    end
  end
end
