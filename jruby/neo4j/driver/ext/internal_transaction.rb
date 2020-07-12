# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalTransaction
        include ExceptionCheckable
        include RunOverride

        def run(statement, parameters = {})
          check { super(to_statement(statement, parameters)) }
        end

        def commit
          check { super }
        end

        # def rollback
        #   check { super }
        # end
      end
    end
  end
end
