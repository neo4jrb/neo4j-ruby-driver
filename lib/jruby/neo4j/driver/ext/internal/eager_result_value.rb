# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
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
