# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # Prepended onto the Java EagerResult (execute_query result):
        # materialises its records as a Ruby Array.
        module EagerResultValue
          include InternalKeys

          def records
            super.to_a
          end
        end
      end
    end
  end
end
