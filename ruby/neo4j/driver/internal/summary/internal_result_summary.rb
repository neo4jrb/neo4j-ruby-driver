module Neo4j::Driver::Internal::Summary
  class InternalResultSummary < Struct.new(:query, :server_info, :database_info, :query_type, :counters, :plan, :profile, :notifications, :result_available_after, :result_consumed_after)

    alias server server_info
    alias database database_info

    def counters
      @counters || InternalSummaryCounters.EMPTY_STATS
    end

    def plan?
      !@plan.nil?
    end

    def profile?
      !@profile.nil?
    end

    def notifications
      @notifications || Collections.empty_list
    end

    def result_available_after(unit)
      unit.convert(@result_available_after, java.util.concurrent.TimeUnit::MILLISECONDS) unless @result_available_after.nil?
    end

    def result_consumed_after(unit)
      unit.convert(@result_consumed_after, java.util.concurrent.TimeUnit::MILLISECONDS) unless @result_consumed_after.nil?
    end

    def to_s
      "InternalResultSummary{" +
      "query=#{query}"\
      ", server_info=#{server_info}"\
      ", database_info=#{database_info}"\
      ", query_type=#{query_type}"\
      ", counters=#{counters}"\
      ", plan=#{plan}"\
      ", profile=#{profile}"\
      ", notifications=#{notifications}"\
      ", result_available_after=#{result_available_after}"\
      ", result_consumed_after=#{result_consumed_after}"\
      "}"
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
