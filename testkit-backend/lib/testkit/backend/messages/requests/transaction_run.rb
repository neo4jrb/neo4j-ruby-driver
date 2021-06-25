module Testkit::Backend::Messages
  module Requests
    class TransactionRun < Request
      def process
        reference('Result')
      end

      def to_object
        fetch(txId).run(cypher, **to_params)
      end
    end
  end
end