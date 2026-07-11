# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Adapts a `#now_millis` time source (epoch milliseconds) to the driver's
      # monotonic/realtime Clock interface. The MRI counterpart of the jruby
      # `ClockAdapter` that bridges `#now_millis` into a `java.time.Clock`;
      # `DriverFactory#to_clock` wraps testkit-backend's clock in it so the
      # driver internals consume it like any other Clock.
      class ClockAdapter
        def initialize(source)
          @source = source
        end

        def monotonic = @source.now_millis / 1000.0
        def realtime = ::Time.at(@source.now_millis / 1000.0)
      end
    end
  end
end
