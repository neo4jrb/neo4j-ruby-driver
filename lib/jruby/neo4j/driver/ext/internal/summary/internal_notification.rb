# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          # Unwraps the Java notification's Optional severity and category
          # getters to a plain value or nil.
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
