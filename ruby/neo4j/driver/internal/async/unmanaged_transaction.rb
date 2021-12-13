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

        def initialize(connection, bookmark_holder, fetch_size, result_cursors = nil)
          @connection = connection
          @protocol = connection.protocol
          @bookmark_holder = bookmark_holder
          @result_cursors = result_cursors || ResultCursorsHolder.new
          @fetch_size = fetch_size
          @lock = java.util.concurrent.locks.ReentrantLock.new
          @state = State::ACTIVE
          @commit_future, @rollback_future, @cause_of_termination = nil
        end

        def begin_async(initial_bookmark, config)
          @protocol.begin_transaction(@connection, initial_bookmark, config).handle do |_ignore, begin_error|
            unless begin_error.nil?
              case begin_error
              when Neo4j::Driver::Exceptions::AuthorizationExpiredException
                @connection.terminate_and_release(Neo4j::Driver::Exceptions::AuthorizationExpiredException::DESCRIPTION)
              when Neo4j::Driver::Exceptions::ConnectionReadTimeoutException
                @connection.terminate_and_release(begin_error.get_message)
              else
                @connection.release
              end

              raise Util::Futures.as_completion_exception(begin_error)
            end
            self
          end
        end

        def close_async(commit = nil, complete_with_null_if_not_open = nil)
          commit = commit ? true : false
          complete_with_null_if_not_open = complete_with_null_if_not_open.nil? ? true : complete_with_null_if_not_open

          stage = Util::LockUtil.execute_with_lock(@lock) do

            result_stage = if complete_with_null_if_not_open && !open?
                             Util.Futures.completed_with_null
                           elsif @state == State::COMMITTED
                             Util.Futures.failed_future(Neo4j::Driver::Exceptions::ClientException.new(commit ? CANT_COMMIT_COMMITTED_MSG : CANT_ROLLBACK_COMMITTED_MSG))
                           elsif @state == State::ROLLED_BACK
                             Util.Futures.failed_future(Neo4j::Driver::Exceptions::ClientException.new(commit ? CANT_COMMIT_ROLLED_BACK_MSG : CANT_ROLLBACK_ROLLED_BACK_MSG))
                           else
                             if commit
                               Util.Futures.failed_future(Neo4j::Driver::Exceptions::ClientException.new(CANT_COMMIT_ROLLING_BACK_MSG)) unless @rollback_future.nil?

                               if !@commit_future.nil?
                                 @commit_future
                               else
                                 @commit_future = java.util.concurrent.CompletableFuture.new
                               end
                             else
                               Util.Futures.failed_future(Neo4j::Driver::Exceptions::ClientException.new(CANT_ROLLBACK_COMMITTING_MSG)) unless @commit_future.nil?

                               if !@rollback_future.nil?
                                 @rollback_future
                               else
                                 @rollback_future = java.util.concurrent.CompletableFuture.new
                               end
                             end
                           end

            result_stage
          end

          if @state.nil?
            if commit
              target_future = @commit_future
              target_action = -> (throwable) { do_commit_async(throwable).handle(handle_commit_or_rollback(throwable)) }
            else
              target_future = @rollback_future
              target_action = -> (throwable) { do_rollback_async(throwable).handle(handle_commit_or_rollback(throwable)) }
            end

            @result_cursors.retrieve_not_consumed_error.then_compose(target_action).when_complete do |_ignored, throwable|
              handle_transaction_completion(commit, throwable)
            end.when_complete(Util::Futures.future_completing_consumer(target_future))

            stage = target_future
          end

          stage
        end

        def commit_async
          close_async(true, false)
        end

        def rollback_async
          close_async(false, false)
        end

        def run_async(query)
          ensure_can_run_queries
          cursor_stage = @protocol.run_in_unmanaged_transaction(@connection, query, self, @fetch_size).async_result
          @result_cursors << cursor_stage
          cursor_stage.then_compose(Cursor::AsyncResultCursor::map_successful_run_completion_async).then_apply(-> (cursor) { cursor })
        end

        def run_rx(query)
          ensure_can_run_queries
          cursor_stage = @protocol.run_in_unmanaged_transaction(@connection, query, self, @fetch_size).rx_result
          @result_cursors << cursor_stage
          cursor_stage
        end

        def open?
          OPEN_STATES.contains(Util::LockUtil.execute_with_lock(@lock, -> () { @state }))
        end

        def mark_terminated(cause)
          Util::LockUtil.execute_with_lock(@lock) do
            if @state == State::TERMINATED
              unless @cause_of_termination.nil?
                add_suppressed_when_not_captured(@cause_of_termination, cause)
              end
            else
              @state = State::TERMINATED
              @cause_of_termination = cause
            end
          end
        end

        def ensure_can_run_queries
          Util::LockUtil.execute_with_lock(@lock) do
            case @state
            when State::COMMITTED
              raise Neo4j::Driver::Exceptions::ClientException.new('Cannot run more queries in this transaction, it has been committed')
            when State::ROLLED_BACK
              raise Neo4j::Driver::Exceptions::ClientException.new('Cannot run more queries in this transaction, it has been rolled back')
            when State::TERMINATED
              raise Neo4j::Driver::Exceptions::ClientException.new('Cannot run more queries in this transaction, it has either experienced an fatal error or was explicitly terminated', @cause_of_termination)
            end
          end
        end

        private

        def add_suppressed_when_not_captured(current_cause, new_cause)
          if current_cause != new_cause
            none_match = current_cause.get_suppressed.none_match(-> (suppressed) { suppressed == new_cause })

            if none_match
              current_cause.add_suppressed(new_cause)
            end
          end
        end

        def do_commit_async(cursor_failure)
          exception = Util::LockUtil.execute_with_lock(@lock) do
            if @state == State::TERMINATED
              Neo4j::Driver::Exceptions::ClientException.new("Transaction can't be committed. It has been rolled back either because of an error or explicit termination", cursor_failure != @cause_of_termination ? @cause_of_termination : nil)
            else
              nil
            end
          end

          !exception.nil? ? Util::Futures.failed_future(exception) : @protocol.commit_transaction(@connection).then_accept(@bookmark_holder::set_bookmark)
        end

        def do_rollback_async
          Util::LockUtil.execute_with_lock(@lock, -> () { @state }) == State::TERMINATED ? Util::Futures.completed_with_null : @protocol.rollback_transaction(@connection)
        end

        def handle_commit_or_rollback(cursor_failure)
          lambda = -> (_ignore, commit_or_rollback_error) do
            combined_error = Util::Futures.combined_error(cursor_failure, commit_or_rollback_error)

            raise combined_error unless combined_error.nil?

            nil
          end
        end

        def handle_transaction_completion(commit_attempt, throwable)
          Util::LockUtil.execute_with_lock(@lock) do
            @state = if commit_attempt && throwable.nil?
                State::COMMITTED
              else
                State::ROLLED_BACK
              end
          end

          case throwable
          when Neo4j::Driver::Exceptions::AuthorizationExpiredException
            @connection.terminate_and_release(Neo4j::Driver::Exceptions::AuthorizationExpiredException::DESCRIPTION)
          when Neo4j::Driver::Exceptions::ConnectionReadTimeoutException
            @connection.terminate_and_release(throwable.get_message)
          else
            @connection.release # release in background
          end
        end
      end
    end
  end
end
