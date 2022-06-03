# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  # Only call #initialize when sub-classing, for constructing plans, use .plan instead
  class InternalPlan < Struct.new(:operator_type, :arguments, :identifiers, :children)
    # Since a plan with or without profiling looks almost the same, we just keep two impls. of this
    # around to contain the small difference, and share the rest of the code for building plan trees.
    # @param <T>

    class Converter
      def initialize(&plan_creator)
        @plan_creator = plan_creator
      end

      def apply(plan)
        operator_type = plan[:operatorType]

        arguments_value = plan[:args]
        arguments = arguments_value || {}

        identifiers_value = plan[:identifiers]
        identifiers = identifiers_value || []

        children_value = plan[:children]
        children = children_value || []

        @plan_creator.call(operator_type, arguments, identifiers, children, plan)
      end
    end

    EXPLAIN_PLAN = lambda { |operator_type, arguments, identifiers, children, _original_plan_value|
      new(operator_type, arguments, identifiers, children) }

    # Builds a regular plan without profiling information - eg. a plan that came as a result of an `EXPLAIN` query
    EXPLAIN_PLAN_FROM_VALUE = Converter.new(&EXPLAIN_PLAN).method(:apply)

    def self.plan(operator_type, arguments, identifiers, children)
      EXPLAIN_PLAN.call(operator_type, arguments, identifiers, children, nil)
    end
  end
end
