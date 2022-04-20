module Neo4j::Driver
  module Internal
    module Metrics
      class InternalConnectionPoolMetrics
        attr_reader :id, :address, :pool

        def initialize(pool_id, address, pool)
          Internal::Validotor.require_non_nil!(address)
          Internal::Validotor.require_non_nil!(pool)

          @id = pool_id
          @address = address
          @pool = pool

          @closed = Concurrent::AtomicFixnum.new

          # creating = created + failedToCreate
          @creating = Concurrent::AtomicFixnum.new
          @created = Concurrent::AtomicFixnum.new
          @failed_to_create = Concurrent::AtomicFixnum.new

          # acquiring = acquired + timedOutToAcquire + failedToAcquireDueToOtherFailures (which we do not keep track)
          @acquiring = Concurrent::AtomicFixnum.new
          @acquired = Concurrent::AtomicFixnum.new
          @timed_out_to_acquire = Concurrent::AtomicFixnum.new

          @total_acquisition_time = Concurrent::AtomicFixnum.new
          @total_connection_time = Concurrent::AtomicFixnum.new
          @total_in_use_time = Concurrent::AtomicFixnum.new

          @total_in_use_count = Concurrent::AtomicFixnum.new
        end

        def before_creating(conn_event)
          @creating.increment
          conn_event.start
        end

        def after_failed_to_create
          @failed_to_create.increment
          @creating.decrement_and_get
        end

        def after_created(conn_event)
          @created.increment
          @creating.decrement
          elapsed = conn_event.elapsed

          @total_connection_time.increment(elapsed)
        end

        def after_closed
          @closed.increment
        end

        def before_acquiring_or_creating(acquire_event)
          acquire_event.start
          @acquiring.increment
        end

        def after_acquiring_or_creating
          @acquiring.decrement
        end

        def after_acquired_or_created(acquire_event)
          @acquired.increment
          elapsed = acquire_event.elapsed
          @total_acquisition_time.increment(elapsed)
        end

        def after_timed_out_to_acquire_or_create
          @timed_out_to_acquire.increment
        end

        def acquired(in_use_event)
          in_use_event.start
        end

        def released(in_use_event)
          @total_in_use_count.increment
          elapsed = in_use_event.elapsed

          @total_in_use_time.increment(elapsed)
        end

        def in_use
          @pool.in_use_connections(@address)
        end

        def idle
          @pool.idle_connections(@address)
        end

        %i[creating created failed_to_create timed_out_to_acquire total_acquisition_time :total_connection_time
        total_in_use_time total_in_use_count closed acquiring acquired].each do |method|
          define_method(method) { instance_variable_get(method).value }
        end

        def to_s
          "#{@id}[created=#{@created}, closed=#{@closed}, creating=#{@creating}, failed_to_create=#{@failed_to_create}, acquiring=#{@acquiring}, acquired=#{@acquired}, timed_out_to_acquire=#{@timed_out_to_acquire}, in_use=#{@in_use}, idle=#{@idle}, total_acquisition_time=#{@total_acquisition_time}, total_connection_time=#{@total_connection_time}, total_in_use_time=#{@total_in_use_time}, total_in_use_count=#{@totalInUseCount}]"
        end
      end
    end
  end
end
