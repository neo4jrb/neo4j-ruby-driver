module Neo4j::Driver
  module Internal
    module Metrics
      module ConnectionPoolMetricsListener
        DEV_NULL_POOL_METRICS_LISTENER =
          Class.new do
            def before_creating(_listener_event) end

            def after_created(_listener_event) end

            def after_failed_to_create
            end

            def after_closed
            end

            def before_acquiring_or_creating(_acquire_event = nil) end

            def after_acquiring_or_creating
            end

            def after_acquired_or_created(_acquire_event) end

            def after_timed_out_to_acquire_or_create
            end

            def acquired(_in_use_event) end

            def released(_in_use_event) end
          end.new
      end
    end
  end
end
