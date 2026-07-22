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
            def db_hits = scalar(dbHits)
            def records = scalar(rows)
            def page_cache_hits = scalar(pageCacheHits)
            def page_cache_misses = scalar(pageCacheMisses)
            def page_cache_hit_ratio = scalar(pageCacheHitRatio)
            def time = super.or_else(nil)&.to_nanos

            private

            # OptionalLong / OptionalDouble -> Integer / Float, or nil when
            # empty. Mirrors the Java backend's stream().boxed().findFirst()
            # .orElse(null), which handles both without a type switch.
            def scalar(optional) = optional.stream.boxed.find_first.or_else(nil)
          end
        end
      end
    end
  end
end
