# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Runs a managed read transaction on the referenced session (execute_read).
    class SessionReadTransaction < SessionTransaction
      def process
        super(:execute_read)
      end
    end
  end
end
