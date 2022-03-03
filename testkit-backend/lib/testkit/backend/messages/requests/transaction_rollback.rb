module Testkit::Backend::Messages
  module Requests
    class TransactionRollback < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(txId).tap(&:rollback)
      end
    end
  end
end