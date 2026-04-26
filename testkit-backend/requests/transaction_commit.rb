# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Single-field example.
    class TransactionCommit < Data.define(:tx_id)
      include Request

      def execute
        registry.fetch(tx_id).commit
        Response::Transaction.new(id: tx_id)
      end
    end
  end
end
