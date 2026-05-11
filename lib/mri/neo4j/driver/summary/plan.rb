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
      end
    end
  end
end
