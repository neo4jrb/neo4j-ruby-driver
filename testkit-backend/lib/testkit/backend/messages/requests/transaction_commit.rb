module Testkit::Backend::Messages
  module Requests
    class TransactionCommit < Request
      def response
        Responses::Result.new(fetch(txId).tap(&:commit))
      end
    end
  end
end