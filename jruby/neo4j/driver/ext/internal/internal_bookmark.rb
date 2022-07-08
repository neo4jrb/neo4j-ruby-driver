module Neo4j
  module Driver
    module Ext
      module Internal
        module InternalBookmark
          def values
            super.to_set
          end
        end
      end
    end
  end
end
