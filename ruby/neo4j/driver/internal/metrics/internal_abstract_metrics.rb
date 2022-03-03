module Neo4j::Driver
  module Internal
    module Metrics
      class InternalAbstractMetrics
        DEV_NULL_METRICS = Class.new do
                             def before_creating(pool_id, creating_event)
                             end

                             def after_created(pool_id, creating_event)
                             end

                             def after_failed_to_create(pool_id)
                             end

                             def after_closed(pool_id)
                             end

                             def before_acquiring_or_creating(pool_id, acquire_event)
                             end

                             def after_acquiring_or_creating(pool_id)
                             end

                             def after_acquired_or_created(pool_id, acquire_event)
                             end

                             def after_timed_out_to_acquire_or_create(pool_id)
                             end

                             def after_connection_created(pool_id, in_use_event)
                             end

                             def after_connection_released(pool_id, in_use_event)
                             end

                             def create_listener_event
                               ListenerEvent::DEV_NULL_LISTENER_EVENT
                             end

                             def put_pool_metrics(id, address, connection_pool)
                             end

                             def remove_pool_metrics(pool_id)
                             end

                             def connection_pool_metrics
                               java.util.Collections.empty_set
                             end

                             def to_s
                               'Driver metrics not available while driver metrics is not enabled.'
                             end
                           end.new
      end
    end
  end
end
