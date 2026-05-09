# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalPlan
            def args
              arguments&.to_h&.transform_values(&:as_ruby_object)
            end

            def identifiers
              super.to_a
            end

            # this part should probably be included in testkit-backend
            def to_h
              {operator_type:, args:, identifiers:, children: children&.map(&:to_h)}
            end
          end
        end
      end
    end
  end
end
