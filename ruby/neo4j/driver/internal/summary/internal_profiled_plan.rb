# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  class InternalProfiledPlan < InternalPlan
    attr_reader :db_hits, :records, :page_cache_hits, :page_cache_misses, :page_cache_hit_ratio, :time

    PROFILED_PLAN = PlanCreator.new

    # Builds a regular plan without profiling information - eg. a plan that came as a result of an `EXPLAIN` query
    PROFILED_PLAN_FROM_VALUE = Converter.new(PROFILED_PLAN)

    def initialize(operator_type, arguments, identifiers, children, db_hits, records, page_cache_hits, page_cache_misses, page_cache_hit_ratio, time)
      super(operator_type, arguments, identifiers, children)
      @db_hits = db_hits
      @records = records
      @page_cache_hits = page_cache_hits
      @page_cache_misses = page_cache_misses
      @page_cache_hit_ratio = page_cache_hit_ratio
      @time = time
    end

    def page_cache_stats?
      page_cache_hits.positive? || page_cache_misses.positive? || page_cache_hit_ratio.positive?
    end

    class PlanCreator
      def create(operator_type, arguments, identifiers, children, original_plan_value)
        InternalProfiledPlan(
          operator_type, arguments, identifiers, children, original_plan_value['db_hits'].to_i,
          original_plan_value['rows'].to_i, original_plan_value['page_cache_hits'].to_i,
          original_plan_value['page_cache_misses'].to_i, original_plan_value['page_cache_hit_ratio'].to_f,
          original_plan_value['time'].to_i
        )
      end
    end
  end
end
