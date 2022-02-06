module Neo4j::Driver
  module Internal
    module Async
      class NetworkSession

        attr_reader :retry_logic

        def initialize(connection_provider, retry_logic, database_name, mode, bookmark_holder, impersonated_user, fetch_size, logging)
          @connection_provider = connection_provider
          @mode = mode
          @retry_logic = retry_logic
          @log = Logging::PrefixedLogger.new("[#{hash_code}]", logging.get_log(self))
          @bookmark_holder = bookmark_holder
          @database_name_future = database_name.database_name.map { java.util.concurrent.CompletableFuture.completed_future(database_name) }.or_else(java.util.concurrent.CompletableFuture.new)
          @connection_context = NetworkSessionConnectionContext.new(@database_name_future, @bookmark_holder.get_bookmark, impersonated_user)
          @fetch_size = fetch_size
          @transaction_stage = Util::Futures.completed_with_null
          @connection_stage = Util::Futures.completed_with_null
          @result_cursor_stage = Util::Futures.completed_with_null
          @open = java.util.concurrent.atomic.AtomicBoolean.new(true)
        end

        def run_async(query, **config)
          new_result_cursor_stage = build_result_cursor_factory(query, config).then_compose(Cursor::ResultCursorFactory.async_result)
          @result_cursor_stage = new_result_cursor_stage.exceptionally { nil }
          new_result_cursor_stage.then_compose(Cursor::AsyncResultCursor::map_successful_run_completion_async).then_apply { cursor } # convert the return type
        end

        def run_rx(query, **config)
          new_result_cursor_stage = build_result_cursor_factory(query, config).then_compose(Cursor::ResultCursorFactory.rx_result)
          @result_cursor_stage = new_result_cursor_stage.exceptionally { nil }
          new_result_cursor_stage
        end

        def begin_transaction_async(mode = @mode, **config)
          ensure_session_is_open

          # create a chain that acquires connection and starts a transaction
          new_transaction_stage = ensure_no_open_tx_before_starting_tx.then_compose { acquire_connection(mode) }.then_apply do |connection|
            ImpersonationUtil.ensure_impersonation_support(connection, connection.impersonated_user).then_compose do |connection|
              tx = UnmanagedTransaction.new(connection, @bookmark_holder, @fetch_size)
              tx.begin_async(bookmark_holder.get_bookmark, config)
            end
          end

          # update the reference to the only known transaction
          current_transaction_stage = @transaction_stage

          # ignore errors from starting new transaction
          @transaction_stage = new_transaction_stage.exceptionally { nil }.then_compose do |tx|
            if tx
              # new transaction started, keep reference to it
              java.util.concurrent.CompletableFuture.completed_future(tx)
            else
              current_transaction_stage
            end
          end

          new_transaction_stage
        end

        def reset_async
          existing_transaction_or_null.then_accept do |tx|
            tx.mark_terminated unless tx.nil?
          end.then_compose { @connection_stage }.then_compose do |connection|
            if connection
              connection.reset # there exists an active connection, send a RESET message over it
            else
              Util::Futures.completed_with_null
            end
          end
        end

        def last_bookmark
          @bookmark_holder.get_bookmark
        end

        def release_connection_async
          @connection_stage.then_compose do |connection|
            if connection
              # there exists connection, try to release it back to the pool
              connection.release
            else
              # no connection so return null
              Util::Futures.completed_with_null
            end
          end
        end

        def connection_async
          @connection_stage
        end

        def open?
          @open.get
        end

        def close_async
          if @open.compare_and_set(true, false)
            @result_cursor_stage.then_compose do |cursor|
              if cursor
                # there exists a cursor with potentially unconsumed error, try to extract and propagate it
                cursor.discard_all_failure_async
              else
                # no result cursor exists so no error exists
                Util::Futures.completed_with_null
              end
            end.then_compose do |cursor_error|
              close_transaction_and_release_connection.then_apply do |tx_close_error|

                # now we have cursor error, active transaction has been closed and connection has been released
                # back to the pool; try to propagate cursor and transaction close errors, if any
                combined_error = Util::Futures.combined_errors(cursor_error, tx_close_error)
                raise combined_error unless combined_error.nil?

                nil
              end
            end
          end

          Util::Futures.completed_with_null
        end

        def current_connection_is_open?
          @connection_stage.handle do |connection, error|
            error.nil? && # no acquisition error
              connection != nil? # some connection has actually been acquired
            connection.open? # and it's still open
          end
        end

        private

        def build_result_cursor_factory(query, config)
          ensure_session_is_open

          ensure_no_open_tx_before_running_query.then_compose { acquire_connection(@mode) }.then_apply do |connection|
            ImpersonationUtil.ensure_impersonation_support(connection, connection.impersonated_user).then_compose do |connection|
              factory = connection.protocol.run_in_auto_commit_transaction(connection, query, @bookmark_holder, config, @fetch_size)
              java.util.concurrent.CompletableFuture.completed_future(factory)
            rescue Exception => e
              Util::Futures.failed_future(e)
            end
          end
        end

        def acquire_connection(mode)
          current_connection_stage = @connection_stage

          new_connection_stage = @result_cursor_stage.then_compose do |cursor|
            if cursor
              # make sure previous result is fully consumed and connection is released back to the pool
              cursor.pull_all_failure_async
            else
              Util::Futures.completed_with_null if cursor
            end
          end.then_compose do |error|
            #   there is no unconsumed error, so one of the following is true:
            #   1) this is first time connection is acquired in this session
            #   2) previous result has been successful and is fully consumed
            #   3) previous result failed and error has been consumed

            if error
              # there exists unconsumed error, re-throw it
              raise java.util.concurrent.CompletionException.new(error)
            else
              # return existing connection, which should've been released back to the pool by now
              current_connection_stage.exceptionally { nil } if error.nil?
            end
          end.then_compose do |existing_connection|
            if !existing_connection.nil? && existing_connection.open?
              # there somehow is an existing open connection, this should not happen, just a precondition
              raise Neo4j::Driver::Exceptions::IllegalStateException, 'Existing open connection detected'
            end

            @connection_provider.acquire_connection(@connection_context.context_with_mode(mode))
          end

          @connection_stage = new_connection_stage.exceptionally { nil }
          new_connection_stage
        end

        def close_transaction_and_release_connection
          existing_transaction_or_null.then_compose do |tx|
            unless tx.nil?
              # there exists an open transaction, let's close it and propagate the error, if any
              tx.close_async.then_apply { nil }.exceptionally { error }
            end

            # no open transaction so nothing to close
            Util::Futures.completed_with_null
          end.then_compose do |tx_close_error|
            # then release the connection and propagate transaction close error, if any
            release_connection_async.then_apply { tx_close_error }
          end
        end

        def ensure_no_open_tx_before_running_query
          ensure_no_open_tx('Queries cannot be run directly on a session with an open transaction; either run from within the transaction or use a different session.')
        end

        def ensure_no_open_tx_before_starting_tx
          ensure_no_open_tx('You cannot begin a transaction on a session with an open transaction; either run from within the transaction or use a different session.')
        end

        def ensure_no_open_tx(error_message)
          existing_transaction_or_null.then_accept do |tx|
            raise Neo4j::Driver::Exceptions::TransactionNestingException, error_message unless tx.nil?
          end
        end

        def existing_transaction_or_null
          # handle previous connection acquisition and tx begin failures
          @transaction_stage.exceptionally { nil }.then_apply do |tx|
            !tx.nil? && tx.open? ? tx : nil
          end
        end

        def ensure_session_is_open
          unless @open.get
            raise Neo4j::Driver::Exceptions::ClientException, 'No more interaction with this session are allowed as the current session is already closed.'
          end
        end

        # The {@link NetworkSessionConnectionContext#mode} can be mutable for a session connection context
        class NetworkSessionConnectionContext
          # This bookmark is only used for rediscovery.
          # It has to be the initial bookmark given at the creation of the session.
          # As only that bookmark could carry extra system bookmarks
          attr_reader :database_name_future, :mode, :rediscovery_bookmark, :impersonated_user

          def initialize(database_name_future, bookmark, impersonated_user)
            @database_name_future = database_name_future
            @rediscovery_bookmark = bookmark
            @impersonated_user = impersonated_user
          end

          def context_with_mode(mode)
            @mode = mode
            self
          end
        end
      end
    end
  end
end
