module Testkit::Backend::Messages
  module Requests
    class TransactionClose < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(txId).tap(&:close)
      end
    end
  end
end
