# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Multi-field example with nested data (params, txMeta).
    class SessionRun < Data.define(:session_id, :cypher, :params, :tx_meta, :timeout)
      include Request

      def execute
        config = { timeout: timeout_seconds, metadata: Cypher.decode_value_map(tx_meta) }.compact
        result = registry.fetch(session_id).run(cypher, Cypher.decode_value_map(params), config)
        Response::Result.new(id: registry.store(result), keys: result.keys.map(&:to_s))
      end

      private

      def timeout_seconds
        timeout && timeout / 1000.0
      end
    end
  end
end
