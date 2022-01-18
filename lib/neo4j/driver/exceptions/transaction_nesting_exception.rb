# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # This exception indicates a user is nesting new transaction with an on-going transaction (unmanaged and/or auto-commit).
      class TransactionNestingException < ClientException
        def initialize(message)
          super(message)
        end
      end
    end
  end
end
