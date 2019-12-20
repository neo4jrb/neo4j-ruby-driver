# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Retry
        DEFAULT_MAX_RETRY_TIME = 30
        INITIAL_RETRY_DELAY = 1
        RETRY_DELAY_MULTIPLIER = 2.0
        RETRY_DELAY_JITTER_FACTOR = 0.2

        class ExponentialBackoffRetryLogic
          def initialize(max_retry_time = nil, logger = nil)
            @max_retry_time = max_retry_time || DEFAULT_MAX_RETRY_TIME
            @log = logger
          end

          def retry
            next_delay = INITIAL_RETRY_DELAY
            start_time = nil
            errors = nil
            loop do
              return yield
            rescue Exceptions::Neo4jException => error
              if can_retry_on?(error)
                curr_time = current_time
                start_time ||= curr_time
                elapsed_time = curr_time - start_time
                if elapsed_time < @max_retry_time
                  delay_with_jitter = compute_delay_with_jitter(next_delay)
                  @log&.warn("Transaction failed and will be retried in #{delay_with_jitter}ms", error)
                  sleep(delay_with_jitter) # verify time units
                  next_delay *= RETRY_DELAY_MULTIPLIER
                  (errors ||= []) << error
                  next
                end
              end
              add_suppressed(error, errors)
              raise error
            end
          end

          private

          def can_retry_on?(error)
            error.is_a?(Exceptions::SessionExpiredException) ||
              error.is_a?(Exceptions::ServiceUnavailableException) ||
              transient_error?(error)
          end

          def transient_error?(error)
            # Retries should not happen when transaction was explicitly terminated by the user.
            # Termination of transaction might result in two different error codes depending on where it was
            # terminated. These are really client errors but classification on the server is not entirely correct and
            # they are classified as transient.
            error.is_a?(Exceptions::TransientException) &&
              !%w[Neo.TransientError.Transaction.Terminated Neo.TransientError.Transaction.LockClientStopped]
                 .include?(error.code)
          end

          def compute_delay_with_jitter(delay)
            jitter = delay * RETRY_DELAY_JITTER_FACTOR
            min = delay - jitter
            max = delay + jitter
            @rand ||= Random.new
            @rand.rand(min..max)
          end

          def current_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end

          def add_suppressed(error, suppressed_errors)
            suppressed_errors&.reject(&error.method(:equal?))&.each(&error.method(:add_suppressed))
          end
        end
      end
    end
  end
end
