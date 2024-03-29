module Testkit::Backend::Messages
  module Requests
    class TransactionRun < Request
      def response
        Responses::Result.new(fetch(tx_id).run(cypher, **to_params))
      end
    end
  end
end