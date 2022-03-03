module Testkit::Backend::Messages
  module Requests
    class TransactionCommit < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(txId).tap(&:commit)
      end
    end
  end
end