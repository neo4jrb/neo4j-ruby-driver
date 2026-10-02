# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Runs a query within the referenced explicit transaction and returns a
    # Result reference.
    class TransactionRun < Request
      def response
        Responses::Result.new(fetch(tx_id).run(cypher, **decode(params)))
      end
    end
  end
end
