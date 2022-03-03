module Neo4j::Driver
  module Internal
    module Util
      # Since {@link java.time.Clock} is only available in Java 8, use our own until we drop java 7 support.
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
