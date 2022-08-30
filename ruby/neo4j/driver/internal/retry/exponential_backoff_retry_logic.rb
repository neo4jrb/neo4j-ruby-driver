# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    module Retry
      class ExponentialBackoffRetryLogic
        DEFAULT_MAX_RETRY_TIME = 30.seconds
        INITIAL_RETRY_DELAY = 1.second
        RETRY_DELAY_MULTIPLIER = 2.0
        RETRY_DELAY_JITTER_FACTOR = 0.2

        def initialize(max_retry_time, event_executor_group, logger = nil)
          @max_retry_time = max_retry_time || DEFAULT_MAX_RETRY_TIME
          @event_executor_group = event_executor_group
          @log = logger
        end

        def retry
          errors = nil
          start_time = nil
          next_delay = INITIAL_RETRY_DELAY
          begin
            yield
          rescue StandardError => error
            if can_retry_on?(error)
              curr_time = Util::Clock::System.time
              start_time ||= curr_time
              elapsed_time = curr_time - start_time
              if elapsed_time < @max_retry_time
                delay_with_jitter = compute_delay_with_jitter(next_delay)
                @log&.warn { "Transaction failed and will be retried in #{delay_with_jitter}ms\n#{error}" }
                sleep(delay_with_jitter)
                next_delay *= RETRY_DELAY_MULTIPLIER
                errors = record_error(error, errors)
                retry
              end
            end
            add_suppressed(error, errors)
            raise error
          end
        end

        def retry_async(&work)
          result_future = Concurrent::Promises.resolvable_future
          execute_work_in_event_loop(result_future, &work)
          result_future
        end

        protected

        def can_retry_on?(error)
          error.is_a?(Exceptions::SessionExpiredException) ||
            error.is_a?(Exceptions::ServiceUnavailableException) ||
            transient_error?(error)
        end

        private

        def extract_possible_termination_cause(error)
          # Having a dedicated "TerminatedException" inheriting from ClientException might be a good idea.
          error.is_a? Exceptions::ClientException && error.cause || error
        end

        def execute_work_in_event_loop(result_future, &work)
          # this is the very first time we execute given work
          event_executor = @event_executor_group.next

          event_executor.execute do
            execute_work(result_future, -1, INITIAL_RETRY_DELAY, nil, &work)
          end
        end

        def retry_work_in_event_loop(result_future, error, start_time, delay, errors, &work)
          # work has failed before, we need to schedule retry with the given delay
          event_executor = event_executor_group.next

          delay_with_jitter = compute_delay_with_jitter(delay)
          @log.warn("Async transaction failed and is scheduled to retry in " + delay_with_jitter + "s", error);

          event_executor.schedule(->() { execute_work(result_future, start_time, delay * multiplier, errors, &work) },
                                  DurationNormalizer.milliseconds(delay_with_jitter),
                                  java.util.concurrent.TimeUnit::MILLISECONDS)
        end

        def execute_work(result_future, start_time, retry_delay, errors, &work)
          begin
            work_stage = work.call
          rescue StandardError => error
            # work failed in a sync way, attempt to schedule a retry
            retry_on_error(result_future, start_time, retry_delay, error, errors, &work)
            return
          end

          work_stage.on_resolution do |fulfilled, result, completion_error|
            error = Futures.completion_exception_cause(completion_error)
            if error
              # work failed in async way, attempt to schedule a retry
              retry_on_error(result_future, work, start_time, retry_delay, error, errors)
            else
              result_future.fulfill(result)
            end
          end
        end

        def retry_on_error(result_future, start_time, retry_delay, throwable, errors, &work)
          error = extract_possible_termination_cause(throwable)
          if can_retry_on?(error)
            current_time = Util::Clock::System.time
            start_time ||= current_time

            elapsed_time = current_time - start_time
            if elapsed_time < @max_retry_time
              errors = record_error(error, errors)
              retry_work_in_event_loop(result_future, error, start_time, retry_delay, errors, &work)
              return
            end
          end

          add_suppressed(throwable, errors)
          result_future.reject(throwable)
        end

        def compute_delay_with_jitter(delay)
          jitter = delay * RETRY_DELAY_JITTER_FACTOR
          min = delay - jitter
          max = delay + jitter
          @rand ||= Random.new
          @rand.rand(min..max)
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

        def record_error(error, errors)
          (errors || []) << error
        end

        def add_suppressed(error, suppressed_errors)
          suppressed_errors&.reject(&error.method(:equal?))&.each(&error.method(:add_suppressed)) if error.is_a? Exceptions::Neo4jException
        end
      end
    end
  end
end
