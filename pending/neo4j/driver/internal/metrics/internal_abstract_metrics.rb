module Neo4j::Driver
  module Internal
    module Metrics
      class InternalAbstractMetrics
        DEV_NULL_METRICS =
          Class.new do
            def before_creating(_pool_id, _creating_event) end

            def after_created(_pool_id, _creating_event) end

            def after_failed_to_create(_pool_id) end

            def after_closed(_pool_id) end

            def before_acquiring_or_creating(_pool_id, _acquire_event) end

            def after_acquiring_or_creating(_pool_id) end

            def after_acquired_or_created(_pool_id, _acquire_event) end

            def after_timed_out_to_acquire_or_create(_pool_id) end

            def after_connection_created(_pool_id, _in_use_event) end

            def after_connection_released(_pool_id, _in_use_event) end

            def create_listener_event
              ListenerEvent::DEV_NULL_LISTENER_EVENT
            end

            def put_pool_metrics(_id, _address, _connection_pool) end

            def remove_pool_metrics(_pool_id) end

            def connection_pool_metrics
              Set.new
            end

            def to_s
              'Driver metrics not available while driver metrics is not enabled.'
            end
          end.new
      end
    end
  end
end
