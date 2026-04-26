# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionBeginTransaction < Data.define(:session_id, :tx_meta, :timeout)
      include Request

      def execute
        # NOTE: Session#begin_transaction currently ignores tx_meta/timeout —
        # honoured here for API parity once the driver supports them.
        tx = registry.fetch(session_id).begin_transaction
        Response::Transaction.new(id: registry.store(tx))
      end
    end
  end
end
