# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalSession
        include BookmarksHolder
        include ErrorHandling
        extend AutoClosable

        auto_closable :begin_transaction

        def initialize(connection_provider, mode, retry_logic = nil, logging = nil)
          super()
          @open = Concurrent::AtomicBoolean.new(true)
          @connection_provider = connection_provider
          @mode = mode
          @retry_logic = retry_logic
        end

        def run(statement, parameters = {}, config = {})
          ensure_session_is_open
          ensure_no_open_tx_before_running_query
          acquire_connection(@mode)
          @result = @connection.protocol.run_in_auto_commit_transaction(
            @connection, Query.new(statement, parameters), self, config
          )
        end

        def read_transaction(**config, &block)
          transaction(Neo4j::Driver::AccessMode::READ, config, &block)
        end

        def write_transaction(**config, &block)
          transaction(Neo4j::Driver::AccessMode::WRITE, config, &block)
        end

        def close
          return unless @open.make_false
          begin
            @result&.finalize
            @result&.failure
          ensure
            close_transaction_and_release_connection
          end
        end

        def release_connection
          @connection&.release
        end

        def begin_transaction(**config)
          private_begin_transaction(@mode, config)
        end

        def last_bookmark
          Bookmark.from([*bookmarks&.max])
        end

        def open?
          @open.true?
        end

        private

        def private_begin_transaction(mode, config)
          ensure_session_is_open
          ensure_no_open_tx_before_starting_tx
          acquire_connection(mode)
          @transaction = InternalTransaction.new(@connection, self).begin(bookmarks, config)
        end

        def transaction(mode, config)
          @retry_logic.retry do
            tx = private_begin_transaction(mode, config)
            result = yield tx
            tx.commit
            result
          rescue StandardError => e
            tx&.rollback
            raise e
          ensure
            tx&.close
          end
        end

        def acquire_connection(mode)
          # make sure previous result is fully consumed and connection is released back to the pool
          @result&.failure

          # there is no unconsumed error, so one of the following is true:
          #   1) this is first time connection is acquired in this session
          #   2) previous result has been successful and is fully consumed
          #   3) previous result failed and error has been consumed

          raise Exceptions::IllegalStateException, 'Existing open connection detected' if @connection&.open?
          @connection = @connection_provider.acquire_connection(mode)
        end

        def close_transaction_and_release_connection
          @transaction&.close
        ensure
          @transaction = nil
          release_connection
        end

        def ensure_session_is_open
          return if open?
          raise Exceptions::ClientException,
                'No more interaction with this session are allowed as the current session is already closed.'
        end

        def ensure_no_open_tx_before_running_query
          ensure_no_open_tx('Statements cannot be run directly on a session with an open transaction; ' \
                            'either run from within the transaction or use a different session.')
        end

        def ensure_no_open_tx_before_starting_tx
          ensure_no_open_tx('You cannot begin a transaction on a session with an open transaction; ' \
                            'either run from within the transaction or use a different session.')
        end

        def ensure_no_open_tx(error_message)
          raise Exceptions::ClientException, error_message if @transaction&.open?
        end
      end
    end
  end
end
