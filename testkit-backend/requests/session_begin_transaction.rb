# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Begins an explicit transaction on the referenced session and returns a
    # Transaction reference.
    class SessionBeginTransaction < Request
      def process
        reference('Transaction')
      end

      def to_object
        fetch(session_id).begin_transaction(metadata: decode(tx_meta), timeout: timeout_duration)
      end
    end
  end
end
