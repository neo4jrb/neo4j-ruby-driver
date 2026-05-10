# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Server-emitted notification (e.g. "this query has a missing index").
      # Mirrors org.neo4j.driver.summary.Notification.
      class Notification
        attr_reader :code, :title, :description, :severity_level, :severity, :category, :position

        def initialize(data)
          @code = data[:code]
          @title = data[:title]
          @description = data[:description]
          # Old wire format used :severity, newer uses :severityLevel.
          @severity_level = data[:severityLevel] || data[:severity]
          @severity = @severity_level
          @category = data[:category]
          @position = data[:position] && Position.new(data[:position])
        end

        # Inner type — character offset / line / column where the
        # notification applies in the query text.
        class Position
          attr_reader :offset, :line, :column

          def initialize(position_data)
            @offset = position_data[:offset]
            @line = position_data[:line]
            @column = position_data[:column]
          end
        end
      end
    end
  end
end
