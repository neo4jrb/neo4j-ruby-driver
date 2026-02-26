# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    class DelegatingTransaction
      delegate :run, :open?, to: :@tx

      def initialize(tx)
        @tx = tx
      end
    end
  end
end
