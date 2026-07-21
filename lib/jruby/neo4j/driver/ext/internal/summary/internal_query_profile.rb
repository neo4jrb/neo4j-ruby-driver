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

            def time
              duration = super # Optional<Duration>
              duration.get.to_nanos if duration.present?
            end

            private

            # OptionalLong / OptionalDouble -> Integer / Float, or nil when empty.
            def scalar(optional)
              return unless optional.present?

              optional.respond_to?(:as_double) ? optional.as_double : optional.as_long
            end
          end
        end
      end
    end
  end
end
