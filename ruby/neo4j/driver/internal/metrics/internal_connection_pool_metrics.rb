module Neo4j::Driver
  module Internal
    module Metrics
      class InternalConnectionPoolMetrics
        include ConnectionPoolMetricsListener

        attr_reader :id, :address, :pool, :creating, :created, :failed_to_create, :timed_out_to_acquire, :total_acquisition_time,
                    :total_connection_time, :total_in_use_time, :total_in_use_count, :closed, :acquiring, :acquired

        def initialize(pool_id, address, pool)
          java.util.Objects.require_non_null(address)
          java.util.Objects.require_non_null(pool)

          @id = pool_id
          @address = address
          @pool = pool

          @closed = java.util.concurrent.atomic.AtomicLong.new

          # creating = created + failedToCreate
          @creating = java.util.concurrent.atomic.AtomicInteger.new
          @created = java.util.concurrent.atomic.AtomicLong.new
          @failed_to_create = java.util.concurrent.atomic.AtomicLong.new

          # acquiring = acquired + timedOutToAcquire + failedToAcquireDueToOtherFailures (which we do not keep track)
          @acquiring = java.util.concurrent.atomic.AtomicInteger.new
          @acquired = java.util.concurrent.atomic.AtomicLong.new
          @timed_out_to_acquire = java.util.concurrent.atomic.AtomicLong.new

          @total_acquisition_time = java.util.concurrent.atomic.AtomicLong.new
          @total_connection_time = java.util.concurrent.atomic.AtomicLong.new
          @total_in_use_time = java.util.concurrent.atomic.AtomicLong.new

          @total_in_use_count = java.util.concurrent.atomic.AtomicLong.new
        end

        def before_creating(conn_event)
          creating.increment_and_get
          conn_event.start
        end

        def after_failed_to_create
          failed_to_create.increment_and_get
          creating.decrement_and_get
        end

        def after_created(conn_event)
          created.increment_and_get
          creating.decrement_and_get
          elapsed = conn_event.elapsed

          total_connection_time.add_and_get(elapsed)
        end

        def after_closed
          closed.increment_and_get
        end

        def before_acquiring_or_creating(acquire_event)
          acquire_event.start
          acquiring.increment_and_get
        end

        def after_acquiring_or_creating
          acquiring.decrement_and_get
        end

        def after_acquired_or_created(acquire_event)
          acquired.increment_and_get
          elapsed = acquire_event.elapsed
          total_acquisition_time.add_and_get(elapsed)
        end

        def after_timed_out_to_acquire_or_create
          timed_out_to_acquire.increment_and_get
        end

        def acquired(in_use_event)
          in_use_event.start
        end

        def released(in_use_event)
          @total_in_use_count.increment_and_get
          elapsed = in_use_event.elapsed

          total_in_use_time.add_and_get(elapsed)
        end

        def in_use
          pool.in_use_connections(address)
        end

        def idle
          pool.idle_connections(address)
        end

        def to_s
          "#{id}[created=#{created}, closed=#{closed}, creating=#{creating}, failed_to_create=#{failed_to_create}, acquiring=#{acquiring}, acquired=#{acquired}, timed_out_to_acquire=#{timed_out_to_acquire}, in_use=#{in_use}, idle=#{idle}, total_acquisition_time=#{total_acquisition_time}, total_connection_time=#{total_connection_time}, total_in_use_time=#{total_in_use_time}, total_in_use_count=#{totalInUseCount}]"
        end
      end
    end
  end
end
