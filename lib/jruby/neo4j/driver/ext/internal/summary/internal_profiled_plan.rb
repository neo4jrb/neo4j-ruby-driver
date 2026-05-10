# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          # Adds dbHits / rows to the Plan payload. Mirrors MRI's
          # Neo4j::Driver::Summary::Profile#to_h.
          module InternalProfiledPlan
            def to_h
              super.merge('dbHits' => db_hits, 'rows' => records)
            end
          end
        end
      end
    end
  end
end
