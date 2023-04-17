module Testkit::Backend::Messages
  module Requests
    class SessionBeginTransaction < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(session_id).begin_transaction(metadata: decode(tx_meta), timeout: timeout_duration)
      end
    end
  end
end