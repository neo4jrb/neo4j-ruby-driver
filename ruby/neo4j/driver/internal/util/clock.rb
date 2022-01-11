module Neo4j::Driver
  module Internal
    module Util
      # Since {@link java.time.Clock} is only available in Java 8, use our own until we drop java 7 support.
      module Clock
        # SYSTEM = new(java.lang.System.current_time_millis, java.lang.Thread.sleep(java.lang.System.current_time_millis))
      end
    end
  end
end
