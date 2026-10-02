# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Closes the referenced explicit transaction and returns a Transaction reference.
    class TransactionClose < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(tx_id).tap(&:close)
      end
    end
  end
end
