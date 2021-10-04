module Testkit::Backend::Messages
  module Requests
    class RetryableNegative < Retryable
      def process_request
        process
      end

      def process
        raise Neo4j::Driver::Exceptions::ClientException if errorId.blank?
      end
    end
  end
end