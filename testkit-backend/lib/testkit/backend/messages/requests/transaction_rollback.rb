module Testkit::Backend::Messages
  module Requests
    class TransactionRollback < Request
      def response
        Responses::Result.new(fetch(txId).tap(&:rollback))
      end
    end
  end
end