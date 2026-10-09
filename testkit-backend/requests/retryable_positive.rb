# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Lets the running managed transaction commit: signals a successful retry
    # attempt and produces no response.
    class RetryablePositive < Retryable
      def process; end
    end
  end
end
