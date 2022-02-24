module Neo4j::Driver
  module Internal
    module Metrics
      module  ConnectionPoolMetricsListener
        DEV_NULL_POOL_METRICS_LISTENER = Class.new do
                                           def before_creating(listener_event)
                                           end

                                           def after_created(listener_event)
                                           end

                                           def after_failed_to_create
                                           end

                                           def after_closed
                                           end

                                           def before_acquiring_or_creating(acquire_event)
                                           end

                                           def after_acquiring_or_creating
                                           end

                                           def after_acquiring_or_creating
                                           end

                                           def after_acquired_or_created(acquire_event)
                                           end

                                           def after_timed_out_to_acquire_or_create
                                           end

                                           def acquired(in_use_event)
                                           end

                                           def released(in_use_event)
                                           end
                                         end.new
      end
    end
  end
end
