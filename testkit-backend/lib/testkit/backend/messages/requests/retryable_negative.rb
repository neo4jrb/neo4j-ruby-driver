module Testkit::Backend::Messages
  module Requests
    class RetryableNegative < Retryable
      def process_request
        process
      end

      def process
        raise error_id.present? ? fetch(error_id) : RollbackException
      end
    end
  end
end