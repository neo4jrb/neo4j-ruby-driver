module Neo4j::Driver
  module Internal
    module Async
      class UnmanagedTransaction
        class State
          # The transaction is running with no explicit success or failure marked
          ACTIVE = 'active'

          # This transaction has been terminated either because of explicit {@link Session#reset()} or because of a fatal connection error.
          TERMINATED = 'terminated'

          # This transaction has successfully committed
          COMMITTED = 'committed'

          # This transaction has been rolled back
          ROLLED_BACK = 'rolled_back'
        end

        CANT_COMMIT_COMMITTED_MSG = "Can't commit, transaction has been committed"
        CANT_ROLLBACK_COMMITTED_MSG = "Can't rollback, transaction has been committed"
        CANT_COMMIT_ROLLED_BACK_MSG = "Can't commit, transaction has been rolled back"
        CANT_ROLLBACK_ROLLED_BACK_MSG = "Can't rollback, transaction has been rolled back"
        CANT_COMMIT_ROLLING_BACK_MSG = "Can't commit, transaction has been requested to be rolled back"
        CANT_ROLLBACK_COMMITTING_MSG = "Can't rollback, transaction has been requested to be committed"
        OPEN_STATES = [State::ACTIVE, State::TERMINATED]
        attr :connection

        def initialize(connection, bookmark_holder, fetch_size, result_cursors = ResultCursorsHolder.new)
          @connection = connection
          @protocol = connection.protocol
          @bookmark_holder = bookmark_holder
          @result_cursors = result_cursors
          @fetch_size = fetch_size
          @lock = Util::Mutex.new
          @state = State::ACTIVE
        end

        def begin_async(initial_bookmark, config)
          @protocol.begin_transaction(@connection, initial_bookmark, config)
          self
        rescue Neo4j::Driver::Exceptions::AuthorizationExpiredException
          @connection.terminate_and_release(Neo4j::Driver::Exceptions::AuthorizationExpiredException::DESCRIPTION)
          raise
        rescue Neo4j::Driver::Exceptions::ConnectionReadTimeoutException => begin_error
          @connection.terminate_and_release(begin_error.message)
          raise
        rescue
          @connection.release
          raise
        end

        def close_async(commit = false, complete_with_null_if_not_open = true)
          @lock.synchronize do
            if complete_with_null_if_not_open && !open?
              nil
            elsif @state == State::COMMITTED
              raise Neo4j::Driver::Exceptions::ClientException, commit ? CANT_COMMIT_COMMITTED_MSG : CANT_ROLLBACK_COMMITTED_MSG
            elsif @state == State::ROLLED_BACK
              raise Neo4j::Driver::Exceptions::ClientException, commit ? CANT_COMMIT_ROLLED_BACK_MSG : CANT_ROLLBACK_ROLLED_BACK_MSG
            else
              if commit
                if @rollback_pending
                  raise Neo4j::Driver::Exceptions::ClientException, CANT_COMMIT_ROLLING_BACK_MSG
                elsif @commit_pending
                  @commit_pending
                else
                  @commit_pending = true
                  nil
                end
              else
                if @commit_pending
                  raise Neo4j::Driver::Exceptions::ClientException, CANT_ROLLBACK_COMMITTING_MSG
                elsif @rollback_pending
                  @rollback_pending
                else
                  @rollback_pending = true
                  nil
                end
              end
            end
          end ||
            begin
              if commit
                target_future = @commit_pending
                target_action = lambda { |throwable|
                  do_commit_async(throwable)
                  handle_commit_or_rollback(throwable)
                }
              else
                target_future = @rollback_pending
                target_action = lambda { |throwable|
                  do_rollback_async
                  handle_commit_or_rollback(throwable)
                }
              end

              @result_cursors.retrieve_not_consumed_error.then(&target_action)
              handle_transaction_completion(commit, nil)
              target_future
            rescue => throwable
              handle_transaction_completion(commit, throwable)
            end
        end

        def commit_async
          close_async(true, false)
        end

        def rollback_async
          close_async(false, false)
        end

        def run_async(query)
          ensure_can_run_queries
          cursor = @protocol.run_in_unmanaged_transaction(@connection, query, self, @fetch_size).async_result
          @result_cursors << cursor
          cursor.map_successful_run_completion_async
        end

        def run_rx(query)
          ensure_can_run_queries
          cursor_stage = @protocol.run_in_unmanaged_transaction(@connection, query, self, @fetch_size).rx_result
          @result_cursors << cursor_stage
          cursor_stage
        end

        def open?
          OPEN_STATES.include?(@lock.synchronize { @state })
        end

        def mark_terminated(cause)
          @lock.synchronize do
            if @state == State::TERMINATED
              add_suppressed_when_not_captured(@cause_of_termination, cause) if @cause_of_termination
            else
              @state = State::TERMINATED
              @cause_of_termination = cause
            end
          end
        end

        def ensure_can_run_queries
          @lock.synchronize do
            case @state
            when State::COMMITTED
              raise Neo4j::Driver::Exceptions::ClientException, 'Cannot run more queries in this transaction, it has been committed'
            when State::ROLLED_BACK
              raise Neo4j::Driver::Exceptions::ClientException, 'Cannot run more queries in this transaction, it has been rolled back'
            when State::TERMINATED
              raise Neo4j::Driver::Exceptions::ClientException, 'Cannot run more queries in this transaction, it has either experienced an fatal error or was explicitly terminated', @cause_of_termination
            end
          end
        end

        private

        def add_suppressed_when_not_captured(current_cause, new_cause)
          if current_cause != new_cause
            none_match = current_cause.get_suppressed.none? { |suppressed| suppressed == new_cause }

            if none_match
              current_cause.add_suppressed(new_cause)
            end
          end
        end

        def do_commit_async(cursor_failure)
          exception = @lock.synchronize do
            if @state == State::TERMINATED
              Neo4j::Driver::Exceptions::ClientException.new(
                "Transaction can't be committed. It has been rolled back either because of an error or explicit termination",
                cursor_failure != @cause_of_termination ? @cause_of_termination : nil)
            end
          end

          if exception
            Util::Futures.failed_future(exception)
          else
            @protocol.commit_transaction(@connection, @bookmark_holder)
          end
        end

        def do_rollback_async
          if @lock.synchronize { @state } == State::TERMINATED
            Util::Futures.completed_with_null
          else
            @protocol.rollback_transaction(@connection)
          end
        end

        def handle_commit_or_rollback(cursor_failure)
          lambda { |_fulfilled, _value, commit_or_rollback_error|
            combined_error = Util::Futures.combined_error(cursor_failure, commit_or_rollback_error)
            raise combined_error if combined_error
          }
        end

        def handle_transaction_completion(commit_attempt, throwable)
          @lock.synchronize { @state = commit_attempt && throwable.nil? ? State::COMMITTED : State::ROLLED_BACK }

          case throwable
          when Neo4j::Driver::Exceptions::AuthorizationExpiredException
            @connection.terminate_and_release(Neo4j::Driver::Exceptions::AuthorizationExpiredException::DESCRIPTION)
          when Neo4j::Driver::Exceptions::ConnectionReadTimeoutException
            @connection.terminate_and_release(throwable.message)
          else
            @connection.release # release in background
          end
        end
      end
    end
  end
end
