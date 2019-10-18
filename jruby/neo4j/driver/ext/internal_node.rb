# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalNode
        def labels
          super.map(&:to_sym)
        end
      end
    end
  end
end
