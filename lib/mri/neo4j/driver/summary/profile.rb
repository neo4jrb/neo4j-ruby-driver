# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Plan plus per-step execution stats. Mirrors the driver-6.2 public
      # QueryProfile, whose getters are all optional: an absent stat stays
      # nil (distinguishable from a real 0) rather than collapsing to 0, so
      # the backend can omit it — Feature:API:Summary:Profile:OptionalStats.
      # The JRuby flavor gets the same nil-vs-0 distinction from
      # Ext::Internal::Summary::InternalQueryProfile.
      class Profile < Plan
        attr_reader :db_hits, :records, :page_cache_hits, :page_cache_misses,
                    :page_cache_hit_ratio, :time

        def initialize(profile_data)
          super
          @db_hits = profile_data[:dbHits]
          @records = profile_data[:rows] || profile_data[:records]
          @page_cache_hits = profile_data[:pageCacheHits]
          @page_cache_misses = profile_data[:pageCacheMisses]
          @page_cache_hit_ratio = profile_data[:pageCacheHitRatio]
          @time = profile_data[:time]
        end
      end
    end
  end
end
