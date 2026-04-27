# frozen_string_literal: true

module TestkitBackend
  # Raised inside a managed-tx block when testkit signals
  # RetryableNegative with an empty errorId — i.e. "the test code
  # itself raised an exception, please surface it as a FrontendError."
  # safely_execute catches this and emits Response::FrontendError.
  class ClientGeneratedError < StandardError; end
end
