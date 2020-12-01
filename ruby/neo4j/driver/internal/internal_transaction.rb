module Neo4j::Driver
  module Internal
    class InternalTransaction
      include Ext::ExceptionCheckable
      include Ext::RunOverride

      delegate :open?, to: :@tx

      def initialize(tx)
        @tx = tx
      end

      def commit
        check do
          org.neo4j.driver.internal.util.Futures.blockingGet(@tx.commitAsync) do
            terminateConnectionOnThreadInterrupt("Thread interrupted while committing the transaction")
          end
        end
      end

      def rollback
        check do
          org.neo4j.driver.internal.util.Futures.blockingGet(@tx.rollbackAsync) do
            terminateConnectionOnThreadInterrupt("Thread interrupted while rolling back the transaction")
          end
        end
      end

      def close
        check do
          org.neo4j.driver.internal.util.Futures.blockingGet(@tx.closeAsync) do
            terminateConnectionOnThreadInterrupt("Thread interrupted while closing the transaction")
          end
        end
      end

      def run(query, parameters = {})
        check do
          cursor = org.neo4j.driver.internal.util.Futures.blockingGet(@tx.runAsync(to_statement(query, parameters), false)) do
            terminateConnectionOnThreadInterrupt("Thread interrupted while running query in transaction")
          end
          org.neo4j.driver.internal.InternalResult.new(@tx.connection, cursor)
        end
      end

      private

      def terminateConnectionOnThreadInterrupt(reason)
        @tx.connection.terminateAndRelease(reason)
      end
    end
  end
end
