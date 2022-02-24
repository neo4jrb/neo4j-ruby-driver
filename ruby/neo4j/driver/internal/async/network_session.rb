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
          @database_name_future = database_name.database_name&.then(&Concurrent::Promises.method(:fulfilled_future)) ||
            Concurrent::Promises.resolvable_future
          @connection_context = NetworkSessionConnectionContext.new(@database_name_future, @bookmark_holder.bookmark, impersonated_user)
          @fetch_size = fetch_size
          @transaction_stage = Util::Futures.completed_with_null
          @connection_stage = Util::Futures.completed_with_null
          @result_cursor_stage = Util::Futures.completed_with_null
          @open = Concurrent::AtomicBoolean.new(true)
        end

        def run_async(query, **config)
          @log.debug { "called run_async: #{query}" }
          new_result_cursor_stage = build_result_cursor_factory(query, config).then_flat(&:async_result)
          @result_cursor_stage = new_result_cursor_stage.rescue {}
          @log.debug { "result_cursor_stage=#{@result_cursor_stage}" }
          new_result_cursor_stage.then_flat(&:map_successful_run_completion_async)
        end

        def run_rx(query, **config)
          new_result_cursor_stage = build_result_cursor_factory(query, config).then_flat(Cursor::ResultCursorFactory.rx_result)
          @result_cursor_stage = new_result_cursor_stage.rescue {}
          new_result_cursor_stage
        end

        def begin_transaction_async(mode = @mode, **config)
          @log.debug { 'calling begin_transaction_async' }
          ensure_session_is_open

          # create a chain that acquires connection and starts a transaction
          new_transaction_stage =
            ensure_no_open_tx_before_starting_tx
              .then_flat { acquire_connection(mode) }
              .then { |connection| ImpersonationUtil.ensure_impersonation_support(connection, connection.impersonated_user) }
              .then_flat do |connection|
              tx = UnmanagedTransaction.new(connection, @bookmark_holder, @fetch_size)
              tx.begin_async(bookmark_holder.get_bookmark, config)
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
          @connection_stage.then_flat do |connection|
            # there exists connection, try to release it back to the pool
            connection&.release ||
              # no connection so return null
              Util::Futures.completed_with_null
          end
        end

        def connection_async
          @connection_stage
        end

        def open?
          @open.true?
        end

        def close_async
          if @open.make_false
            @result_cursor_stage.then_flat do |cursor|
              if cursor
                # there exists a cursor with potentially unconsumed error, try to extract and propagate it
                cursor.discard_all_failure_async
              else
                # no result cursor exists so no error exists
                Util::Futures.completed_with_null
              end
            end.then_flat do |cursor_error|
              close_transaction_and_release_connection.then do |tx_close_error|
                # now we have cursor error, active transaction has been closed and connection has been released
                # back to the pool; try to propagate cursor and transaction close errors, if any
                combined_error = Util::Futures.combined_errors(cursor_error, tx_close_error)
                raise combined_error if combined_error
                nil
              end
            end
          end

          Util::Futures.completed_with_null
        end

        def current_connection_open?
          @connection_stage.chain do |_fulfilled, connection, error|
            error.nil? && # no acquisition error
              connection&.open? # some connection has actually been acquired and it's still open
          end
        end

        private

        def build_result_cursor_factory(query, config)
          @log.debug { "build_result_cursor_factory" }
          ensure_session_is_open
          @log.debug { "build_result_cursor_factory1" }

          ensure_no_open_tx_before_running_query.tap { |it| @log.debug { "ensure_no_open_tx_before_running_query=#{it}" } }
                                                .then_flat { acquire_connection(@mode) }
                                                .then { |connection| @log.debug { "build_result_cursor_factory3" }; ImpersonationUtil.ensure_impersonation_support(connection, connection.impersonated_user) }
                                                .then_flat do |connection|
            @log.debug { 'factory creation' }
            factory = connection.protocol.run_in_auto_commit_transaction(connection, query, @bookmark_holder, config,
                                                                         @fetch_size)
            @log.debug { 'fulfilled future with factory' }
            Concurrent::Promises.fulfilled_future(factory)
          rescue StandardError => e
            Util::Futures.failed_future(e)
          end
        end

        def acquire_connection(mode)
          @log.debug { "acquire_connection(#{mode})" }
          current_connection_stage = @connection_stage

          new_connection_stage = @result_cursor_stage.then_flat do |cursor|
            @log.debug { "acquire_connection1" }
            # make sure previous result is fully consumed and connection is released back to the pool
            cursor&.pull_all_failure_async || Util::Futures.completed_with_null
          end.then_flat do |error|
            @log.debug { "acquire_connection2" }
            #   there is no unconsumed error, so one of the following is true:
            #   1) this is first time connection is acquired in this session
            #   2) previous result has been successful and is fully consumed
            #   3) previous result failed and error has been consumed

            if error
              # there exists unconsumed error, re-throw it
              raise error
            else
              # return existing connection, which should've been released back to the pool by now
              current_connection_stage.rescue {}
            end
          end.then_flat do |existing_connection|
            @log.debug { "acquire_connection3" }
            if existing_connection&.open?
              # there somehow is an existing open connection, this should not happen, just a precondition
              raise Neo4j::Driver::Exceptions::IllegalStateException.new('Existing open connection detected')
            end

            @connection_provider.acquire_connection(@connection_context.context_with_mode(mode))
          end

          @connection_stage = new_connection_stage.rescue {}
          @log.debug { "exiting...acquire_connection(#{mode}):#{new_connection_stage}" }
          new_connection_stage
        end

        def close_transaction_and_release_connection
          existing_transaction_or_null.then_flat do |tx|
            if tx
              # there exists an open transaction, let's close it and propagate the error, if any
              tx.close_async.then {}.rescue(&:itself)
            else
              # no open transaction so nothing to close
              Util::Futures.completed_with_null
            end
          end.then_flat do |tx_close_error|
            # then release the connection and propagate transaction close error, if any
            release_connection_async.then { tx_close_error }
          end
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
          @log.debug { "transaction_stage=#{@transaction_stage}" }
          # handle previous connection acquisition and tx begin failures
          @transaction_stage.rescue {}.then { |tx| tx if tx&.open? }.tap { |it| @log.debug { "existing_transaction_or_null=#{it}" } }
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
