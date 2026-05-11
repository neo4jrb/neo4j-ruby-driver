# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Plan plus per-step execution stats (db_hits, rows). Mirrors
      # org.neo4j.driver.summary.ProfiledPlan.
      class Profile < Plan
        attr_reader :db_hits, :records, :rows

        def initialize(profile_data)
          super
          @db_hits = profile_data[:dbHits] || 0
          @records = profile_data[:rows] || profile_data[:records] || 0
          @rows = @records
        end

        def to_h
          super.merge(db_hits: @db_hits, records: @records)
        end
      end
    end
  end
end
