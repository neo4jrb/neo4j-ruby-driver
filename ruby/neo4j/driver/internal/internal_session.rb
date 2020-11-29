module Neo4j::Driver
  module Internal
    class InternalSession
      extend AutoClosable
      include Ext::ConfigConverter
      include Ext::ExceptionCheckable
      include Ext::RunOverride
      java_import org.neo4j.driver.internal.util.Futures

      attr_reader :session

      delegate :open?, :last_bookmark, to: :session
      auto_closable :begin_transaction

      def initialize(session)
        @session = session
      end

      def run(query, parameters = {}, config = {})
        check do
          cursor = Futures.blockingGet(session.runAsync(to_statement(query, parameters), to_java_config(org.neo4j.driver.TransactionConfig, config), false)) do
            terminateConnectionOnThreadInterrupt("Thread interrupted while running query in session")
          end

          # query executed, it is safe to obtain a connection in a blocking way
          connection = Futures.getNow(session.connectionAsync)
          org.neo4j.driver.internal.InternalResult.new(connection, cursor)
        end
      end

      def close
        check do
          Futures.blockingGet(session.closeAsync) do
            terminateConnectionOnThreadInterrupt("Thread interrupted while closing the session")
          end
        end
      end

      def begin_transaction(**config)
        check do
          tx = Futures.blockingGet(session.beginTransactionAsync(to_java_config(org.neo4j.driver.TransactionConfig, config))) do
            org.neo4j.driver.internal.terminateConnectionOnThreadInterrupt("Thread interrupted while starting a transaction")
          end
          org.neo4j.driver.internal.InternalTransaction.new(tx)
        end
      end

      def read_transaction(**config, &block)
        transaction(org.neo4j.driver.AccessMode::READ, **config, &block)
      end

      def write_transaction(**config, &block)
        transaction(org.neo4j.driver.AccessMode::WRITE, **config, &block)
      end

      private

      # work around jruby issue https://github.com/jruby/jruby/issues/5603
      Struct.new('Wrapper', :object)

      def transaction(mode, **config)
        # use different code path compared to async so that work is executed in the caller thread
        # caller thread will also be the one who sleeps between retries;
        # it is unsafe to execute retries in the event loop threads because this can cause a deadlock
        # event loop thread will bock and wait for itself to read some data
        check do
          @session.retry_logic.retry do
            tx = private_begin_transaction(mode, config)
            result = reverse_check { yield tx }
            tx.commit if tx.open? # if a user has not explicitly committed or rolled back the transaction
            Struct::Wrapper.new(result)
          ensure
            tx&.close
          end.object
        end
      end

      def private_begin_transaction(mode, **config)
        tx = Futures.blockingGet(session.beginTransactionAsync(mode, to_java_config(org.neo4j.driver.TransactionConfig, config))) do
          terminateConnectionOnThreadInterrupt("Thread interrupted while starting a transaction")
        end
        org.neo4j.driver.internal.InternalTransaction.new(tx)
      end

      def terminateConnectionOnThreadInterrupt(reason)
        connection = Futures.getNow(session.connectionAsync)
      rescue Exception
        nil # ignore errors because handing interruptions is best effort
      ensure
        connection&.terminateAndRelease(reason)
      end
    end
  end
end
