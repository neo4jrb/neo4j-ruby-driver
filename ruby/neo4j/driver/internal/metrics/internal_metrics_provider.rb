module Neo4j::Driver
  module Internal
    module Metrics
      class InternalMetricsProvider
        include MetricsProvider

        attr_reader :metrics
        alias metrics_listener metrics

        def initialize(clock, logging)
          @metrics = InternalMetrics.new(clock, logging)
        end

        def metrics_enabled?
          true
        end
      end
    end
  end
end
