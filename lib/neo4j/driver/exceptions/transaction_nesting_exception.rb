# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # This exception indicates a user is nesting new transaction with an on-going transaction (unmanaged and/or auto-commit).
      class TransactionNestingException < ClientException
      end
    end
  end
end
