module Neo4j::Driver
  module Internal
    module Async
      class NetworkSession
        attr_reader :retry_logic

        def initialize(connection_provider, retry_logic, database_name, mode, bookmark_holder, impersonated_user, fetch_size, logger)
          @connection_provider = connection_provider
          @mode = mode
          @retry_logic = retry_logic
          @log = Logging::PrefixedLogger.new("[#{hash}]", logger)
          @bookmark_holder = bookmark_holder
          @database_name = database_name.database_name
          @connection_context = NetworkSessionConnectionContext.new(@database_name, @bookmark_holder.bookmark, impersonated_user)
          @fetch_size = fetch_size
          @open = Concurrent::AtomicBoolean.new(true)
        end

        def run_async(query, **config)
          new_result_cursor = build_result_cursor_factory(query, config).async_result
          @result_cursor = new_result_cursor
          new_result_cursor.map_successful_run_completion_async
        end

        def run_rx(query, **config)
          new_result_cursor_stage = build_result_cursor_factory(query, config).then_flat(Cursor::ResultCursorFactory.rx_result)
          @result_cursor_stage = new_result_cursor_stage.rescue {}
          new_result_cursor_stage
        end

        def begin_transaction_async(mode = @mode, **config)
          ensure_session_is_open

          # create a chain that acquires connection and starts a transaction
          new_transaction_stage =
            ensure_no_open_tx_before_starting_tx
          acquire_connection(mode).then do |connection|
            ImpersonationUtil.ensure_impersonation_support(connection, connection.impersonated_user)
            tx = UnmanagedTransaction.new(connection, @bookmark_holder, @fetch_size)
            tx.begin_async(@bookmark_holder.bookmark, config)
          end

          # update the reference to the only known transaction
          current_transaction_stage = @transaction_stage

          # ignore errors from starting new transaction
          @transaction_stage = new_transaction_stage.rescue {}.then_flat do |tx|
            if tx
              # new transaction started, keep reference to it
              Concurrent::Promises.fulfilled_future(tx)
            else
              current_transaction_stage
            end
          end

          new_transaction_stage
        end

        def reset_async
          existing_transaction_or_null
            .then_accept { |tx| tx&.mark_terminated }
            .then_flat { @connection_stage }
            .then_flat do |connection|
            # there exists an active connection, send a RESET message over it
            connection&.reset || Util::Futures.completed_with_null
          end
        end

        def last_bookmark
          @bookmark_holder.bookmark
        end

        def release_connection_async
          @connection&.release
        end

        def connection_async
          @connection
        end

        def open?
          @open.true?
        end

        def close_async
          return unless @open.make_false
          # there exists a cursor with potentially unconsumed error, try to extract and propagate it
          @result_cursor&.discard_all_failure_async
        ensure
          close_transaction_and_release_connection
        end

        def current_connection_open?
          @connection&.open? # some connection has actually been acquired and it's still open
        end

        private

        def build_result_cursor_factory(query, config)
          ensure_session_is_open
          ensure_no_open_tx_before_running_query
          connection = acquire_connection(@mode)
          ImpersonationUtil.ensure_impersonation_support(connection, connection.impersonated_user)
          connection.protocol.run_in_auto_commit_transaction(connection, query, @bookmark_holder, config,
                                                             @fetch_size)
        end

        def acquire_connection(mode)
          # make sure previous result is fully consumed and connection is released back to the pool
          @result_cursor&.pull_all_failure_async
          if @connection&.open?
            # there somehow is an existing open connection, this should not happen, just a precondition
            raise Neo4j::Driver::Exceptions::IllegalStateException.new('Existing open connection detected')
          end

          @connection = @connection_provider.acquire_connection(@connection_context.context_with_mode(mode))
        end

        def close_transaction_and_release_connection
          existing_transaction_or_null&.close_async
        ensure
          release_connection_async
        end

        def ensure_no_open_tx_before_running_query
          ensure_no_open_tx('Queries cannot be run directly on a session with an open transaction; either run from within the transaction or use a different session.')
        end

        def ensure_no_open_tx_before_starting_tx
          ensure_no_open_tx('You cannot begin a transaction on a session with an open transaction; either run from within the transaction or use a different session.')
        end

        def ensure_no_open_tx(error_message)
          existing_transaction_or_null.then do |tx|
            raise Neo4j::Driver::Exceptions::TransactionNestingException.new(error_message) if tx
          end
        end

        def existing_transaction_or_null
          @transaction if @transaction&.open?
        end

        def ensure_session_is_open
          unless @open.true?
            raise Neo4j::Driver::Exceptions::ClientException.new('No more interaction with this session are allowed as the current session is already closed.')
          end
        end

        # The {@link NetworkSessionConnectionContext#mode} can be mutable for a session connection context
        class NetworkSessionConnectionContext
          # This bookmark is only used for rediscovery.
          # It has to be the initial bookmark given at the creation of the session.
          # As only that bookmark could carry extra system bookmarks
          attr_reader :database_name, :mode, :rediscovery_bookmark, :impersonated_user

          def initialize(database_name, bookmark, impersonated_user)
            @database_name = database_name
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
