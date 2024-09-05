module Neo4j::Driver
  module Internal
    module Reactive
      class AbstractReactiveSession
        delegate :last_bookmarks, to: :@session

        # RxSession accept a network session as input.
        # The network session different from async session that it provides ways to both run for Rx and Async
        # Note: Blocking result could just build on top of async result. However, Rx result cannot just build on top of
        # async result.
        def initialize(session)
          @session = session
        end

        def do_begin_transaction(config, tx_type = nil)
          create_single_item_publisher(
            lambda do
              tx_future = nil
              @session.begin_transaction_async(config, tx_type).when_complete do |tx, completion_error|
                if tx.nil?
                  release_connection_before_returning(tx_future, completion_error)
                else
                  tx_future.complete(create_transaction(tx))
                end
              end
              tx_future
            end,
            Neo4j::Driver::Exceptions::IllegalStateException.new("Unexpected condition, begin transaction call has completed successfully with transaction being null")
            )
        end

        def begin_transaction(mode, config)
          create_single_item_publisher(
            lambda do
              tx_future = nil
              @session.begin_transaction_async(mode, config).when_complete do |tx, completion_error|
                if tx.nil?
                  release_connection_before_returning(tx_future, completion_error)
                else
                  tx_future.complete(create_transaction(tx))
                end
              end
              tx_future
            end,
            Neo4j::Driver::Exceptions::IllegalStateException.new("Unexpected condition, begin transaction call has completed successfully with transaction being null")
            )
        end

        def run_transaction(mode, work, config)
          repeatable_work = Flux.using_when(begin_transaction(mode, config), work, 
                              -> (tx) { close_transaction(tx, true) },
                              -> (tx, error) { close_transaction(tx, false) },
                              -> (tx) { close_transaction(tx, false) }
                            )
          @session.retry_logic.retry_rx(repeatable_work)
        end

        private def release_connection_before_returning(return_future, completion_error)
          # We failed to create a result cursor, so we cannot rely on result cursor to clean-up resources.
          # Therefore, we will first release the connection that might have been created in the session and then notify
          # the error.
          # The logic here shall be the same as `SessionPullResponseHandler#afterFailure`.
          # The reason we need to release connection in session is that we made `rxSession.close()` optional;
          # Otherwise, session.close shall handle everything for us.
          error = completion_error

          if error.is_a? Neo4j::Driver::Exceptions::TransactionNestingException
            return_future.complete_exceptionally(error)
          else
            @session.release_connection_async.when_complete do |_, close_error|
              return_future.complete_exceptionally(Util::Future.combine_errors(error, close_error))
            end
          end
        end

        def do_close
          create_empty_publisher(@session::close_async)
        end
      end
    end
  end
end
