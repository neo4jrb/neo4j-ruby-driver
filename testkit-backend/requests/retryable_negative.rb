# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Aborts the running managed transaction: re-raises the referenced error,
    # or rolls back (RollbackException) when no error id is given.
    class RetryableNegative < Retryable
      def process_request
        process
      end

      def process
        raise error_id.present? ? fetch(error_id) : RollbackException
      end
    end
  end
end
