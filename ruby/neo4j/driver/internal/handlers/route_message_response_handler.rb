module Neo4j::Driver
  module Internal
    module Handlers
      class RouteMessageResponseHandler < Struct.new(:completable_future)
        def on_success(metadata)
          begin
            completable_future.complete(metadata[:rt])
          rescue StandardError => ex
            completable_future.complete_exceptionally(ex)
          end
        end

        def on_failure(error)
          completable_future.complete_exceptionally(error)
        end

        def on_record(fields)
          completable_future.complete_exceptionally(java.lang.UnsupportedOperationException.new("Route is not expected to receive records: #{fields}"))
        end
      end
    end
  end
end
