# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Base for managed read/write transactions: drives the frontend's retry
    # loop (RetryableTry/RetryableDone), running the nested requests of each
    # attempt until a Retryable reply ends it.
    class SessionTransaction < Request
      def process(method)
        fetch(session_id).send(method, metadata: decode(tx_meta), timeout: timeout_duration) do |tx|
          tx_id = store(tx)
          @command_processor.process_response(named_entity('RetryableTry', id: tx_id))
          until @command_processor.next_request.is_a?(Retryable)
          end
        ensure
          delete(tx_id)
        end
        named_entity('RetryableDone')
      end
    end
  end
end
