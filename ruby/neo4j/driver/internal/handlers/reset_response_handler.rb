module Neo4j::Driver
  module Internal
    module Handlers
      class ResetResponseHandler
        include Spi::ResponseHandler

        def initialize(message_dispatcher, completion_future = nil)
          @message_dispatcher = message_dispatcher
          @completion_future = completion_future
        end

        def on_success(_metadata = {})
          reset_completed(true)
        end

        def on_failure(_error)
          reset_completed(false)
        end

        def on_record(_fields)
          raise java.lang.UnsupportedOperationException
        end

        private def reset_completed(_success)
          @message_dispatcher.clear_current_error

          unless @completion_future.nil?
            @completion_future.complete(nil)
          end
        end
      end
    end
  end
end
