module Testkit::Backend::Messages
  module Requests
    class RetryableNegative < Retryable
      def process_request
        process
      end

      def process
        raise errorId.present? ? fetch(errorId) : RollbackException
      end
    end
  end
end