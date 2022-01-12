module Neo4j::Driver
  module Internal
    module Metrics
      class InternalMetricsProvider
        attr_reader :metrics

        def initialize(clock, logging)
          @metrics = InternalMetrics.new(clock, logging)
        end

        def metrics_listener
          metrics
        end

        def metrics_enabled?
          true
        end
      end
    end
  end
end
