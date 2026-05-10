# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Query execution plan tree. Mirrors org.neo4j.driver.summary.Plan.
      class Plan
        attr_reader :operator_type, :identifiers, :arguments, :children

        def initialize(plan_data)
          @operator_type = plan_data[:operatorType]
          @identifiers = plan_data[:identifiers] || []
          @arguments = plan_data[:args] || {}
          @children = (plan_data[:children] || []).map { |child| self.class.new(child) }
        end

        # camelCase string-keyed serialisation for cross-protocol use.
        def to_h
          {
            'operatorType' => @operator_type,
            'identifiers' => @identifiers,
            'args' => stringify_args(@arguments),
            'children' => @children.map(&:to_h)
          }
        end

        private

        def stringify_args(value)
          case value
          when Hash  then value.transform_keys(&:to_s).transform_values { stringify_args(it) }
          when Array then value.map { stringify_args(it) }
          else value
          end
        end
      end
    end
  end
end
