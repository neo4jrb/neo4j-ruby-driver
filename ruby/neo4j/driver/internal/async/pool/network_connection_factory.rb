module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class NetworkConnectionFactory
          attr_reader :clock, :metrics_listener, :logger

          def initialize(clock, metrics_listener, logger)
            @clock = clock
            @metrics_listener = metrics_listener
            @logger = logger
          end

          def create_connection(channel, pool)
            NetworkConnection.new(channel, pool, clock, metrics_listener, @logger)
          end
        end
      end
    end
  end
end
