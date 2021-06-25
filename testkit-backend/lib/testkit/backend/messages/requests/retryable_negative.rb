module Testkit::Backend::Messages
  module Requests
    class RetryableNegative < Retryable
      def process_request
        process
      end

      def process
        raise RollbackException
      end
    end
  end
end