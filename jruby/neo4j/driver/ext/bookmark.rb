# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Bookmark
        module ClassMethods
          def from(*values)
            super(java.util.HashSet.new(values))
          end
        end
      end
    end
  end
end
