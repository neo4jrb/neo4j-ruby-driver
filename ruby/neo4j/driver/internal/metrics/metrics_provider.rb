module Neo4j::Driver
  module Internal
    module Metrics
      module MetricsProvider
        METRICS_DISABLED_PROVIDER = Class.new do
          def metrics
            # To outside users, we forbidden their access to the metrics API
            raise ClientException, "Driver metrics not enabled. To access driver metrics, you need to enabled driver metrics in the driver's configuration."
          end

          def metrics_listener()
            # Internally we can still register callbacks to this empty metrics listener.
            DEV_NULL_METRICS
          end
        end
      end
    end
  end
end
