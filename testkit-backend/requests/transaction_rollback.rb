module TestkitBackend
  module Requests
    class TransactionRollback < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(tx_id).tap(&:rollback)
      end
    end
  end
end