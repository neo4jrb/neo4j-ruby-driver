# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionWriteTransaction < SessionTransaction
      def process
        super(:execute_write)
      end
    end
  end
end
