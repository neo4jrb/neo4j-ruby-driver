module Testkit::Backend::Messages
  module Requests
    class TransactionClose < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(tx_id).tap(&:close)
      end
    end
  end
end
