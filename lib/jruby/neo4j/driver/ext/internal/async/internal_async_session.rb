# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Async
          module InternalAsyncSession
            include ConfigConverter
            include RunOverride
            include AsyncConverter

            def run_async(statement, parameters = {}, config = {})
              to_future(
                java_method(:runAsync, [org.neo4j.driver.Query, org.neo4j.driver.TransactionConfig])
                  .call(to_statement(statement, parameters), to_java_config(Neo4j::Driver::TransactionConfig, **config)))
            end
          end
        end
      end
    end
  end
end
