# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  # Only call #initialize when sub-classing, for constructing plans, use .plan instead
  class InternalPlan < Struct.new(:operator_type, :arguments, :identifiers, :children)
    # Since a plan with or without profiling looks almost the same, we just keep two impls. of this
    # around to contain the small difference, and share the rest of the code for building plan trees.
    # @param <T>
    class PlanCreator
      def create(operator_type, arguments, identifiers, children, original_plan_value)
        InternalPlan.new(operator_type, arguments, identifiers, children)
      end
    end

    class Converter
      def initialize(plan_creator)
        @plan_creator = plan_creator
      end

      def apply(plan)
        operator_type = plan['operator_type'].to_s

        arguments_value = plan['args']
        arguments = arguments_value.nil? ? {} : arguments_value.as_map(&Values.of_value)

        identifiers_value = plan['identifiers']
        identifiers = identifiers_value.nil? ? [] : identifiers_value.as_list(&Values.of_string)

        children_value = plan['children']
        children = children_value.nil? ? [] : children_value.as_list(self)

        @plan_creator.create(operator_type, arguments, identifiers, children, plan)
      end
    end

    EXPLAIN_PLAN = PlanCreator.new

    # Builds a regular plan without profiling information - eg. a plan that came as a result of an `EXPLAIN` query
    EXPLAIN_PLAN_FROM_VALUE = Converter.new(EXPLAIN_PLAN)

    def self.plan(operator_type, arguments, identifiers, children)
      EXPLAIN_PLAN.create(operator_type, arguments, identifiers, children, nil)
    end

    def to_s
      "SimplePlanTreeNode{operator_type=#{operator_type}, arguments=#{arguments},"\
      " identifiers=#{identifiers}, children=#{children}}"
    end
  end
end
