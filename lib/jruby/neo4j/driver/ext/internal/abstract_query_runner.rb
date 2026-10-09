# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # Shared run() override for query runners (sessions, transactions):
        # builds a Neo4j::Driver::Query from the Ruby query text and parameters
        # (via RunOverride#to_statement) and routes the call through #check, so a
        # Java exception comes back as the driver's Ruby exception.
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
