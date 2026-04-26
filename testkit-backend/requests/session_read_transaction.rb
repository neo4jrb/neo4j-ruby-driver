# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionReadTransaction < Data.define(:session_id, :tx_meta, :timeout)
      include Request
      include ManagedTransaction

      private

      def driver_method
        :execute_read
      end
    end
  end
end
