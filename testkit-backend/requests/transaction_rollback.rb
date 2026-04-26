# frozen_string_literal: true

module TestkitBackend
  module Requests
    class TransactionRollback < Data.define(:tx_id)
      include Request

      def execute
        registry.fetch(tx_id).rollback
        Response::Transaction.new(id: tx_id)
      end
    end
  end
end
