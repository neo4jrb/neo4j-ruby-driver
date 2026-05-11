# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalProfiledPlan
            def to_h
              super.merge(db_hits:, records:, page_cache_hits:, page_cache_misses:,
                          page_cache_hit_ratio:, time:)
            end
          end
        end
      end
    end
  end
end
