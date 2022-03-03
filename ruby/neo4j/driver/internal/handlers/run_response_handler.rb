module Neo4j::Driver
  module Internal
    module Handlers
      class RunResponseHandler
        attr_reader :query_keys, :result_available_after, :query_id

        def initialize(run_future, metadata_extractor, connection, tx)
          @query_keys = Utils::QueryKeys.empty
          @run_future = run_future
          @metadata_extractor = metadata_extractor
          @connection = connection
          @tx = tx
        end

        def on_success(metadata)
          @query_keys = metadata_extractor.extract_query_keys(metadata)
          @result_available_after = metadata_extractor.extract_result_available_after(metadata)
          @query_id = metadata_extractor.extract_query_id(metadata)

          @run_future.fulfill(nil)
        end

        def on_failure(error)
          if @tx
            @tx.mark_terminated(error)
          elsif error.is_a?(Exceptions::AuthorizationExpiredException)
            connection.terminate_and_release(Exceptions::AuthorizationExpiredException::DESCRIPTION)
          elsif error.is_a?(Exceptions::ConnectionReadTimeoutException)
            connection.terminate_and_release(error.message)
          end
          @run_future.reject(error)
        end

        def on_record(_fields)
          raise 'unsupported operation'
        end
      end
    end
  end
end
