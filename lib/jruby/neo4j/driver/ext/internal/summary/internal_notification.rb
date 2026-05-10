module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalNotification
            def severity_level
              super.or_else(nil)
            end

            def raw_severity_level
              super.or_else(nil)
            end

            def raw_category
              super.or_else(nil)
            end

            def category
              super.or_else(nil)
            end

            # camelCase string-keyed serialisation, matching MRI's
            # Neo4j::Driver::Summary::Notification#to_h. testkit-backend's
            # SummaryPayload calls this so the dict shape is identical
            # whether `summary` is an MRI ResultSummary or a Java one.
            def to_h
              {
                'code' => code,
                'title' => title,
                'description' => description,
                'severityLevel' => severity_level,
                'category' => category,
                'position' => position && {
                  'offset' => position.offset,
                  'line' => position.line,
                  'column' => position.column
                }
              }.compact
            end
          end
        end
      end
    end
  end
end
