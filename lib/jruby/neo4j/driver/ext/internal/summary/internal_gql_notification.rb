# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          # A GqlStatusObject that is also a notification. Unwraps the Java
          # Optionals so the backend sees plain Ruby (an InputPosition or nil,
          # and parsed name strings) — mirroring the InternalNotification ext.
          module InternalGqlNotification
            def position = super.or_else(nil)
            def classification = super.or_else(nil)&.name
            def raw_classification = super.or_else(nil)
            def severity = super.or_else(nil)&.name
            def raw_severity = super.or_else(nil)
          end
        end
      end
    end
  end
end
