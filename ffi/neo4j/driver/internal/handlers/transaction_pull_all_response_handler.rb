# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class TransactionPullAllResponseHandler < PullAllResponseHandler
          def initialize(statement, run_handler, connection, tx, metadata_extractor)
            super(statement, run_handler, connection, metadata_extractor)
            @tx = tx
            @tx.chain run_handler, self
          end

          def after_success(_metadata); end

          def after_failure(_error)
            @tx.mark_terminated
          end
        end
      end
    end
  end
end
