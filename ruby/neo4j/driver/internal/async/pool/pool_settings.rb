module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class PoolSettings
          attr_reader :max_connection_pool_size, :connection_acquisition_timeout, :max_connection_lifetime, :idle_time_before_connection_test

          NOT_CONFIGURED = -1
          DEFAULT_MAX_CONNECTION_POOL_SIZE = 100
          DEFAULT_IDLE_TIME_BEFORE_CONNECTION_TEST = NOT_CONFIGURED
          DEFAULT_MAX_CONNECTION_LIFETIME = 60*60*1000 # in milliseconds
          DEFAULT_CONNECTION_ACQUISITION_TIMEOUT = 60 * 1000 # in milliseconds

          def initialize(max_connection_pool_size, connection_acquisition_timeout, max_connection_lifetime, idle_time_before_connection_test)
            @max_connection_pool_size = max_connection_pool_size
            @connection_acquisition_timeout = connection_acquisition_timeout
            @max_connection_lifetime = max_connection_lifetime
            @idle_time_before_connection_test = idle_time_before_connection_test
          end

          def idle_time_before_connection_test_enabled?
            idle_time_before_connection_test >= 0
          end

          def max_connection_lifetime_enabled
            max_connection_lifetime > 0
          end
        end
      end
    end
  end
end
