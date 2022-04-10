module Neo4j::Driver
  module Internal
    module Handlers
      class NoOpResponseHandler
        INSTANCE = new

        def on_success(metadata)
        end

        def on_failure(error)
        end

        def on_record(fields)
        end
      end
    end
  end
end
