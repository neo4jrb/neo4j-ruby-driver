module Neo4j::Driver
  module Internal
    module Metrics
      class InternalMetrics
        def initialize(clock, logger)
          Validator.require_non_nil!(clock)
          @connection_pool_metrics = java.util.concurrent.ConcurrentHashMap.new
          @clock = clock
          @log = logger
        end

        def put_pool_metrics(pool_id, server_address, pool)
          @connection_pool_metrics[pool_id] = InternalConnectionPoolMetrics.new(pool_id, server_address, pool)
        end

        def remove_pool_metrics(id)
          @connection_pool_metrics.remove(id)
        end

        def before_creating(pool_id, creating_event)
          pool_metrics(pool_id).before_creating(creating_event)
        end

        def after_created(pool_id, creating_event)
          pool_metrics(pool_id).after_created(creating_event)
        end

        def after_failed_to_create(pool_id)
          pool_metrics(pool_id).after_failed_to_create
        end

        def after_closed(pool_id)
          pool_metrics(pool_id).after_closed
        end

        def before_acquiring_or_creating(pool_id, acquire_event)
          pool_metrics(pool_id).before_acquiring_or_creating(acquire_event)
        end

        def after_acquiring_or_creating(pool_id)
          pool_metrics(pool_id).after_acquiring_or_creating
        end

        def after_acquired_or_created(pool_id, acquire_event)
          pool_metrics(pool_id).after_acquired_or_created(acquire_event)
        end

        def after_connection_created(pool_id, in_use_event)
          pool_metrics(pool_id).acquired( in_use_event)
        end

        def after_connection_released(pool_id, in_use_event)
          pool_metrics(pool_id).released( in_use_event)
        end

        def after_timed_out_to_acquire_or_create(pool_id)
          pool_metrics(pool_id).after_timed_out_to_acquire_or_create
        end

        def create_listener_event
          TimeRecorderListenerEvent.new(@clock)
        end

        def connection_pool_metrics
          java.util.Collections.unmodifiable_collection(@connection_pool_metrics.values)
        end

        def to_s
          "PoolMetrics=#{@connection_pool_metrics}"
        end

        private

        def pool_metrics(pool_id)
          pool_metrics = @connection_pool_metrics[pool_id]

          if pool_metrics.nil?
            @log.warn("Failed to find pool metrics with id `#{pool_id}` in #{@connection_pool_metrics}.")
            return ConnectionPoolMetricsListener::DEV_NULL_POOL_METRICS_LISTENER
          end

          pool_metrics
        end
      end
    end
  end
end
