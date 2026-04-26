# frozen_string_literal: true

module TestkitBackend
  module Requests
    class TransactionClose < Data.define(:tx_id)
      include Request

      def execute
        registry.delete(tx_id)&.close
        Response::Transaction.new(id: tx_id)
      end
    end
  end
end
