# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionBeginTransaction < Data.define(:session_id, :tx_meta, :timeout)
      include Request

      def execute
        tx = registry.fetch(session_id).begin_transaction(**tx_options)
        Response::Transaction.new(id: registry.store(tx))
      end

      private

      # testkit sends timeout in milliseconds; the driver expects seconds.
      def tx_options
        {
          metadata: Cypher.decode_value_map(tx_meta),
          timeout: timeout && timeout / 1000.0
        }.compact
      end
    end
  end
end
