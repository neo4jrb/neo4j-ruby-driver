# frozen_string_literal: true

module Neo4j
  module Driver
    # The transaction context yielded to execute_read / execute_write work
    # blocks. It deliberately exposes only #run: the driver owns the lifecycle
    # of a managed transaction (auto-commit on clean return, rollback + retry
    # on failure), so the block must not commit, roll back, or close it.
    #
    # This is Neo4j::Driver::Transaction on both flavours — the JRuby flavour
    # binds the constant to Java's DelegatingTransactionContext — so downstream
    # code prepending onto Neo4j::Driver::Transaction targets the managed
    # context consistently. Explicit transactions (session.begin_transaction)
    # use UnmanagedTransaction, which keeps commit/rollback/close.
    class Transaction
      def initialize(transaction)
        @transaction = transaction
      end

      def run(query, **parameters)
        @transaction.run(query, **parameters)
      end
    end
  end
end
