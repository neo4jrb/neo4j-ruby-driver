# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Rolls back the referenced explicit transaction and returns a Transaction reference.
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
