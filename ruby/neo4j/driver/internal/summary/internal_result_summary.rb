# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  class InternalResultSummary < Struct.new(:query, :server, :database, :query_type, :counters, :plan, :profile,
                                           :notifications, :result_available_after, :result_consumed_after)
    alias has_plan? plan
    alias has_profile? profile

    def initialize(*args)
      super
      self.plan = resolve_plan(plan, profile)
    end

    def counters
      super || InternalSummaryCounters::EMPTY_STATS
    end

    def notifications
      super || []
    end

    private

    # Profiled plan is a superset of plan. This method returns profiled plan if plan is {@code null}.
    #
    # @param plan the given plan, possibly {@code null}.
    # @param profiled_plan the given profiled plan, possibly {@code null}.
    # @return available plan.
    def resolve_plan(plan, profiled_plan)
      plan || profiled_plan
    end
  end
end
