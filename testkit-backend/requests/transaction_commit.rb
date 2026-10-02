# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Commits the referenced explicit transaction and returns a Transaction reference.
    class TransactionCommit < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(tx_id).tap(&:commit)
      end
    end
  end
end
