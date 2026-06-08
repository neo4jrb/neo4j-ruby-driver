# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # The transaction has been terminated, so the work it was running
      # cannot continue. Mirrors
      # org.neo4j.driver.exceptions.TransactionTerminatedException.
      class TransactionTerminatedException < ClientException
      end
    end
  end
end
