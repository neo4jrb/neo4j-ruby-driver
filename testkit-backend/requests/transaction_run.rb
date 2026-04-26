# frozen_string_literal: true

module TestkitBackend
  module Requests
    class TransactionRun < Data.define(:tx_id, :cypher, :params)
      include Request

      def execute
        result = registry.fetch(tx_id).run(cypher, Cypher.decode_value_map(params))
        Response::Result.new(id: registry.store(result), keys: result.keys.map(&:to_s))
      end
    end
  end
end
