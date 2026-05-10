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

            # camelCase string-keyed serialisation, matching MRI's
            # Neo4j::Driver::Summary::Plan#to_h. testkit-backend's
            # SummaryPayload uses it directly so the dict shape is
            # identical whether `summary.plan` is an MRI Plan or a Java one.
            def to_h
              {
                'operatorType' => operator_type,
                'identifiers' => identifiers,
                'args' => args,
                'children' => children&.map(&:to_h)
              }
            end
          end
        end
      end
    end
  end
end
