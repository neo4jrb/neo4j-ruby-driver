# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Returns a node's labels as symbols.
      module InternalNode
        def labels
          super.map(&:to_sym)
        end
      end
    end
  end
end
