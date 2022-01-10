module Neo4j::Driver
  module Internal
    module Handlers
      class TransactionPullResponseCompletionListener
        def initialize(tx)
          @tx = Validator.require_non_nil!(tx)
        end

        def after_success(_metadata) end

        def after_failure(error)
          # always mark transaction as terminated because every error is "acknowledged" with a RESET message
          # so database forgets about the transaction after the first error
          # such transaction should not attempt to commit and can be considered as rolled back
          @tx.mark_terminated(error)
        end
      end
    end
  end
end
