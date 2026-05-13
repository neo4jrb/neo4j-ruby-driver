# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Plan plus per-step execution stats (db_hits, rows). Mirrors
      # org.neo4j.driver.summary.ProfiledPlan.
      class Profile < Plan
        attr_reader :db_hits, :records, :page_cache_hits, :page_cache_misses,
                    :page_cache_hit_ratio, :time

        def initialize(profile_data)
          super
          @db_hits = profile_data[:dbHits] || 0
          @records = profile_data[:rows] || profile_data[:records] || 0
          @page_cache_hits = profile_data[:pageCacheHits] || 0
          @page_cache_misses = profile_data[:pageCacheMisses] || 0
          @page_cache_hit_ratio = profile_data[:pageCacheHitRatio] || 0.0
          @time = profile_data[:time] || 0
        end
      end
    end
  end
end
