# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          # A GqlStatusObject. Hydrate the Java Map<String, Value> diagnostic
          # record to a plain (symbol-keyed) Ruby hash, like the rest of the
          # summary; the GqlNotification subtype adds position/severity/…
          module InternalGqlStatusObject
            def diagnostic_record = super.as_ruby_object
          end
        end
      end
    end
  end
end
