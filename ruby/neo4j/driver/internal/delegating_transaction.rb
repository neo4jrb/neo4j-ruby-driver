# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    class DelegatingTransaction
      def initialize(tx)
        @tx = tx
      end

      def run(query, **parameters)
        @tx.run(query, **parameters)
      end
    end
  end
end
