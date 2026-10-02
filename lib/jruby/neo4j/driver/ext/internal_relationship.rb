# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Returns a relationship's type as a symbol.
      module InternalRelationship
        def type
          super.to_sym
        end
      end
    end
  end
end
