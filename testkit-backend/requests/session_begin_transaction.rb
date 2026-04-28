# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionBeginTransaction < Data.define(:session_id, :tx_meta, :timeout)
      include Request

      def execute
        tx = registry.fetch(session_id).begin_transaction(**tx_options(tx_meta, timeout))
        Response::Transaction.new(id: registry.store(tx))
      end
    end
  end
end
