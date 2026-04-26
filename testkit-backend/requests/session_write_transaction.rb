# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionWriteTransaction < Data.define(:session_id, :tx_meta, :timeout)
      include Request
      include ManagedTransaction

      private

      def driver_method
        :execute_write
      end
    end
  end
end
