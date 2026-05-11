# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Which database the result came from. Java's
      # org.neo4j.driver.summary.DatabaseInfo.
      class DatabaseInfo
        attr_reader :name

        def initialize(db_data)
          @name =
            case db_data
            when String then db_data
            when Hash   then db_data[:name]
            end
        end

        def to_s
          @name || 'unknown'
        end
      end
    end
  end
end
