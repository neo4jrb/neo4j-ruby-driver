module Neo4j::Driver
  module Internal
    module Metrics
      class TimeRecorderListenerEvent
        def start
          @start_time = Util::Clock::System.millis
        end

        def elapsed
          Util::Clock::System.millis - @start_time
        end
      end
    end
  end
end
