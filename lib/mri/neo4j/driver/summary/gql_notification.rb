# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # A GqlStatusObject whose status also maps to a Neo4j notification
      # (the wire status carries a `neo4j_code`). It exposes the extra
      # notification facets — position, classification and severity —
      # which live in the diagnostic record under `_position` /
      # `_classification` / `_severity`.
      #
      # The parsed accessors return nil for a value outside the known enum
      # (the backend renders that as "UNKNOWN"); the raw_* accessors hand
      # back whatever the server sent, untouched.
      class GqlNotification < GqlStatusObject
        def position
          @data.dig(:diagnostic_record, :_position)&.then { Notification::Position.new(it) }
        end

        def raw_classification
          @data.dig(:diagnostic_record, :_classification)
        end

        def classification
          raw_classification if Notification::KNOWN_CATEGORIES.include?(raw_classification)
        end

        def raw_severity
          @data.dig(:diagnostic_record, :_severity)
        end

        def severity
          raw_severity if Notification::KNOWN_SEVERITIES.include?(raw_severity)
        end
      end
    end
  end
end
