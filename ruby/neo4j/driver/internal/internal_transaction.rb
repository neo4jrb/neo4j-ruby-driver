module Neo4j::Driver
  module Internal
    class InternalTransaction
      delegate :open?, to: :@tx

      def initialize(tx)
        @tx = tx
      end

      def commit
        @tx.commit_async
        # org.neo4j.driver.internal.util.Futures.blockingGet(@tx.commit_async) do
        #   terminate_connection_on_thread_interrupt('Thread interrupted while committing the transaction')
        # end
      end

      def rollback
        @tx.rollback_async
        # org.neo4j.driver.internal.util.Futures.blockingGet(@tx.rollback_async) do
        #   terminate_connection_on_thread_interrupt('Thread interrupted while rolling back the transaction')
        # end
      end

      def close
        @tx.close_async
      # org.neo4j.driver.internal.util.Futures.blockingGet(@tx.close_async) do
      #     terminate_connection_on_thread_interrupt('Thread interrupted while closing the transaction')
      #   end
      end

      def run(query, **parameters)
        cursor = @tx.run_async(Query.new(query, **parameters))
        # cursor = org.neo4j.driver.internal.util.Futures.blockingGet(@tx.run_async(to_statement(query, parameters))) do
        #   terminate_connection_on_thread_interrupt('Thread interrupted while running query in transaction')
        # end
        InternalResult.new(@tx.connection, cursor)
      end

      private

      def terminate_connection_on_thread_interrupt(reason)
        @tx.connection.terminate_and_release(reason)
      end
    end
  end
end
