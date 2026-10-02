# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Runs a managed write transaction on the referenced session (execute_write).
    class SessionWriteTransaction < SessionTransaction
      def process
        super(:execute_write)
      end
    end
  end
end
