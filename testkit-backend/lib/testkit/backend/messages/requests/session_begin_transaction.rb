module Testkit::Backend::Messages
  module Requests
    class SessionBeginTransaction < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(sessionId).begin_transaction(metadata: txMeta, timeout: timeout_duration)
      end
    end
  end
end