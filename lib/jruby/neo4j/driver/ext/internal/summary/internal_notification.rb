module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalNotification
            def severity_level
              super.or_else(nil)
            end

            def raw_severity_level
              super.or_else(nil)
            end

            def raw_category
              super.or_else(nil)
            end

            def category
              super.or_else(nil)
            end
          end
        end
      end
    end
  end
end
