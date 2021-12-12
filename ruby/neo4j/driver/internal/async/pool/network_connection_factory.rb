module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class NetworkConnectionFactory
          attr_reader :clock, :metrics_listener, :logging

          def initialize(clock, metrics_listener, logging)
            @clock = clock
            @metrics_listener = metrics_listener
            @logging = logging
          end

          def create_connection(channel, pool)
            NetworkConnection.new(channel, pool, clock, metrics_listener, logging)
          end
        end
      end
    end
  end
end
