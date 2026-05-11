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

        # Backend-friendly Ruby hash. Mirrors JRuby InternalPlan#to_h.
        def to_h
          { operator_type: @operator_type, args: @arguments, identifiers: @identifiers,
            children: @children.map(&:to_h) }
        end
      end
    end
  end
end
