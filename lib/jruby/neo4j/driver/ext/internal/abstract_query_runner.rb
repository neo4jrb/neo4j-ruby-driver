# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # Shared run() override for query runners (sessions, transactions):
        # builds a Java Statement from the Ruby query and parameters and maps
        # any Java exception on the way out.
        module AbstractQueryRunner
          include ExceptionCheckable
          include RunOverride

          def run(statement, **parameters)
            check { super(to_statement(statement, parameters)) }
          end
        end
      end
    end
  end
end
