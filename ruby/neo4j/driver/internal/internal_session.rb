module Neo4j::Driver
  module Internal
    class InternalSession
      extend AutoClosable
      extend Synchronizable
      # include Ext::RunOverride
      delegate :open?, :last_bookmark, to: :@session
      auto_closable :begin_transaction
      sync :close, :begin_transaction, :run, :transaction

      def initialize(session)
        @session = session
      end

      def run(query, parameters = {}, config = {})
        parameters ||= {}
        Validator.require_hash_parameters!(parameters)
        cursor = @session.run_async(Query.new(query, **parameters), **TransactionConfig.new(**config.compact)) do
          terminate_connection_on_thread_interrupt('Thread interrupted while running query in session')
        end.result!

        # query executed, it is safe to obtain a connection in a blocking way
        connection = @session.connection_async
        InternalResult.new(connection, cursor)
      end

      def close
        @session.close_async do
          terminate_connection_on_thread_interrupt("Thread interrupted while closing the session")
        end
      end

      def begin_transaction(**config)
        tx = @session.begin_transaction_async(**config) do
          terminate_connection_on_thread_interrupt("Thread interrupted while starting a transaction")
        end
        InternalTransaction.new(tx)
      end

      def read_transaction(**config, &block)
        transaction(AccessMode::READ, **config, &block)
      end

      def write_transaction(**config, &block)
        transaction(AccessMode::WRITE, **config, &block)
      end

      private

      def transaction(mode, **config)
        # use different code path compared to async so that work is executed in the caller thread
        # caller thread will also be the one who sleeps between retries;
        # it is unsafe to execute retries in the event loop threads because this can cause a deadlock
        # event loop thread will bock and wait for itself to read some data
        @session.retry_logic.retry do
          tx = private_begin_transaction(mode, **config)
          result = yield tx
          tx.commit if tx.open? # if a user has not explicitly committed or rolled back the transaction
          result
        ensure
          tx&.close
        end
      end

      def private_begin_transaction(mode, **config)
        tx = @session.begin_transaction_async(mode, **config) do
          terminate_connection_on_thread_interrupt("Thread interrupted while starting a transaction")
        end
        InternalTransaction.new(tx)
      end

      def terminate_connection_on_thread_interrupt(reason)
        connection = @session.connection_async
      rescue
        nil # ignore errors because handing interruptions is best effort
      ensure
        connection&.terminate_and_release(reason)
      end
    end
  end
end
