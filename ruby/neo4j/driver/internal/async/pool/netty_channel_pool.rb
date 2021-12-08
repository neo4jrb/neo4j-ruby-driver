module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class NettyChannelPool
          # Unlimited amount of parties are allowed to request channels from the pool.
          MAX_PENDING_ACQUIRES = java.lang.Integer::MAX_VALUE

          # Do not check channels when they are returned to the pool.
          RELEASE_HEALTH_CHECK = false

          attr_reader :delegate, :closed, :id, :close_future

          def initialize(address, connector, bootstrap, handler, health_check, acquire_timeout_millis, max_connections)
            java.util.Objects.require_non_null(address)
            java.util.Objects.require_non_null(connector)
            java.util.Objects.require_non_null(handler)
            @id = pool_id(address)
            @delegate = Java::IoNettyChannelPool::FixedChannelPool.new(bootstrap, handler, health_check,
                        Java::IoNettyChannelPool::FixedChannelPool::AcquireTimeoutAction::FAIL, acquire_timeout_millis,
                        max_connections, MAX_PENDING_ACQUIRES, RELEASE_HEALTH_CHECK)
          end

          def close
            if closed.compare_and_set(false, true)
              Util::Futurs.as_completion_stage(delegate.close_async, close_future)
            end
            close_future
          end

          def acquire
            Util::Futurs.as_completion_stage(delegate.acquire)
          end

          def release(channel)
            Util::Futurs.as_completion_stage(delegate.release(channel))
          end

          def is_closed?
            closed.get
          end

          def id
            id
          end

          private

          def pool_id(server_address)
            [server_address.host, server_address.port, self.hash_code]
          end
        end
      end
    end
  end
end
