module Neo4j::Driver
  module Internal
    class InternalTransaction
      delegate :open?, to: :@tx

      def initialize(tx)
        @tx = tx
      end

      def commit
        org.neo4j.driver.internal.util.Futures.blockingGet(@tx.commitAsync) do
          terminateConnectionOnThreadInterrupt("Thread interrupted while committing the transaction")
        end
      end

      def rollback
        org.neo4j.driver.internal.util.Futures.blockingGet(@tx.rollbackAsync) do
          terminateConnectionOnThreadInterrupt("Thread interrupted while rolling back the transaction")
        end
      end

      def close
        org.neo4j.driver.internal.util.Futures.blockingGet(@tx.closeAsync) do
          terminateConnectionOnThreadInterrupt("Thread interrupted while closing the transaction")
        end
      end

      def run(query, parameters = {})
        cursor = org.neo4j.driver.internal.util.Futures.blockingGet(@tx.runAsync(to_statement(query, parameters))) do
          terminateConnectionOnThreadInterrupt("Thread interrupted while running query in transaction")
        end
        InternalResult.new(@tx.connection, cursor)
      end

      private

      def terminateConnectionOnThreadInterrupt(reason)
        @tx.connection.terminateAndRelease(reason)
      end
    end
  end
end
