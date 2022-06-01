module Neo4j::Driver
  module Internal
    module Handlers
      class RouteMessageResponseHandler < Struct.new(:completion_listener)
        include Spi::ResponseHandler

        def on_success(metadata)
          completion_listener.routing_table = metadata[:rt]
        end

        def on_failure(error)
          raise error
        end

        def on_record(fields)
          raise "Route is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
