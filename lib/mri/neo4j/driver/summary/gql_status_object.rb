# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # A GQL status object, sourced from a Bolt 5.6+ summary `statuses`
      # entry. Mirrors org.neo4j.driver.summary.GqlStatusObject. A plain
      # status (e.g. "00000 — successful completion") carries only a status
      # code, a description and a diagnostic record; the GqlNotification
      # subtype adds the notification facets (position / classification /
      # severity).
      class GqlStatusObject
        # The server may omit the standard diagnostic-record keys; the
        # driver fills these defaults (matching Java) while leaving every
        # other key — including ones the server set to an explicit null —
        # exactly as received.
        DIAGNOSTIC_RECORD_DEFAULTS = {
          OPERATION: '', OPERATION_CODE: '0', CURRENT_SCHEMA: '/'
        }.freeze

        attr_reader :gql_status, :status_description

        def initialize(data)
          @data = data
          @gql_status = data[:gql_status]
          @status_description = data[:status_description]
        end

        def diagnostic_record
          DIAGNOSTIC_RECORD_DEFAULTS.merge(@data[:diagnostic_record] || {})
        end
      end
    end
  end
end
