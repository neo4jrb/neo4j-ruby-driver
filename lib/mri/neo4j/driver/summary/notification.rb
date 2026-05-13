# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Server-emitted notification (e.g. "this query has a missing index").
      # Mirrors org.neo4j.driver.summary.Notification.
      class Notification
        attr_reader :code, :title, :description, :severity_level, :severity,
                    :raw_severity_level, :category, :raw_category, :position

        # Severity mapping matches the Java driver's NotificationSeverity:
        # WARNING/INFORMATION/OFF/UNKNOWN. Anything else stays as nil on
        # severity_level but is preserved verbatim in raw_severity_level.
        KNOWN_SEVERITIES = %w[WARNING INFORMATION OFF UNKNOWN].freeze
        KNOWN_CATEGORIES = %w[HINT UNRECOGNIZED UNSUPPORTED PERFORMANCE
                              DEPRECATION GENERIC SECURITY TOPOLOGY SCHEMA].freeze

        def initialize(data)
          @code = data[:code]
          @title = data[:title]
          @description = data[:description]
          # Old wire format used :severity, newer uses :severityLevel.
          @raw_severity_level = data[:severityLevel] || data[:severity]
          @severity_level = KNOWN_SEVERITIES.include?(@raw_severity_level) ? @raw_severity_level : 'UNKNOWN'
          @severity = @raw_severity_level
          @raw_category = data[:category]
          @category = KNOWN_CATEGORIES.include?(@raw_category) ? @raw_category : 'UNKNOWN'
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
