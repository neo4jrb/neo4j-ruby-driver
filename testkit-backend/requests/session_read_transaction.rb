# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionReadTransaction < SessionTransaction
      def process
        super(:execute_read)
      end
    end
  end
end
