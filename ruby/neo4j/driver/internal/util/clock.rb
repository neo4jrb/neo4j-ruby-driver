module Neo4j::Driver
  module Internal
    module Util
      module Clock
        module System
          class << self
            def millis()
              gettime(:millisecond)
            end

            def time()
              gettime(:float_second).seconds
            end

            def sleep(duration)
              super(duration.in_seconds)
            end

            private

            def gettime(unit)
              Process.clock_gettime(Process::CLOCK_MONOTONIC, unit)
            end
          end
        end
      end
    end
  end
end
