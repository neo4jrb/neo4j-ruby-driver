# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          # QueryProfile (driver 6.2) reports each profile stat as an
          # Optional, so an absent stat is distinguishable from a real 0 —
          # unlike the deprecated ProfiledPlan, whose long getters collapse
          # absent to 0. Map empty -> nil (the backend omits nil) and
          # present -> the value; this is what makes
          # Feature:API:Summary:Profile:OptionalStats work. operator_type /
          # args / identifiers / children come from the InternalPlan
          # superclass unchanged.
          module InternalQueryProfile
            def db_hits = long(dbHits)
            def records = long(rows)
            def page_cache_hits = long(pageCacheHits)
            def page_cache_misses = long(pageCacheMisses)
            def page_cache_hit_ratio = double(pageCacheHitRatio)
            def time = super.or_else(nil)&.to_nanos

            private

            # OptionalLong / OptionalDouble -> Integer / Float, or nil when
            # empty. or_else(nil) can't be used: their orElse takes a
            # primitive default, not nil.
            def long(optional) = optional.present? ? optional.as_long : nil
            def double(optional) = optional.present? ? optional.as_double : nil
          end
        end
      end
    end
  end
end
