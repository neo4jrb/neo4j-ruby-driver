module Neo4j::Driver
  module Internal
    module Metrics
      class TimeRecorderListenerEvent
        def initialize(clock)
          @clock = clock
        end

        def start
          @start_time = @clock.millis
        end

        def elapsed
          @clock.millis - @start_time
        end
      end
    end
  end
end
