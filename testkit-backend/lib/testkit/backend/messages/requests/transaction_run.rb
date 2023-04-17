module Testkit::Backend::Messages
  module Requests
    class TransactionRun < Request
      def response
        Responses::Result.new(fetch(tx_id).run(cypher, **decode(params)))
      end
    end
  end
end