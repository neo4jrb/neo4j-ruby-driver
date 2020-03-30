# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ExplicitTransaction
        include ExceptionCheckable
        include RunOverride

        def run(statement, parameters = {})
          check { super(to_statement(statement, parameters)) }
        end
      end
    end
  end
end
