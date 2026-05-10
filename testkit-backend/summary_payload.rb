# frozen_string_literal: true

module TestkitBackend
  # Builds the testkit Summary `data` payload from a driver
  # Summary::ResultSummary. Uses only the public Summary API — no
  # reaching into wire metadata. The Notification/Plan/Profile
  # serialisation lives on those classes themselves (#to_h), this
  # payload class just maps query_type back to the wire string and
  # walks the typed accessors.
  class SummaryPayload < Data.define(:summary)
    INTEGER_COUNTERS = %i[
      nodes_created nodes_deleted relationships_created relationships_deleted
      properties_set labels_added labels_removed indexes_added indexes_removed
      constraints_added constraints_removed system_updates
    ].freeze

    # ResultSummary#query_type returns the typed enum-like symbol; testkit
    # expects the original Bolt wire token. One-line inversion.
    QUERY_TYPE_TO_WIRE = {
      Neo4j::Driver::Summary::QueryType::READ_ONLY    => 'r',
      Neo4j::Driver::Summary::QueryType::WRITE_ONLY   => 'w',
      Neo4j::Driver::Summary::QueryType::READ_WRITE   => 'rw',
      Neo4j::Driver::Summary::QueryType::SCHEMA_WRITE => 's'
    }.freeze

    def to_h
      notifications = summary.notifications
      {
        'database' => summary.database&.name,
        'query' => query_payload,
        'queryType' => QUERY_TYPE_TO_WIRE[summary.query_type],
        'counters' => counters_payload,
        'notifications' => (notifications.empty? ? nil : notifications.map(&:to_h)),
        'plan' => summary.plan&.to_h,
        'profile' => summary.profile&.to_h,
        'resultAvailableAfter' => summary.result_available_after,
        'resultConsumedAfter' => summary.result_consumed_after,
        'serverInfo' => server_info_payload
      }
    end

    private

    def query_payload
      query = summary.query
      {
        'text' => query.text,
        'parameters' => encode_parameters(query.parameters)
      }
    end

    def encode_parameters(params)
      return {} unless params.is_a?(Hash)

      params.transform_keys(&:to_s).transform_values(&Cypher.method(:from_ruby))
    end

    def counters_payload
      counters = summary.counters
      payload = INTEGER_COUNTERS.each_with_object({}) do |key, acc|
        acc[Casing.camel(key)] = counters.public_send(key)
      end
      payload['containsUpdates'] = counters.contains_updates?
      payload['containsSystemUpdates'] = counters.contains_system_updates?
      payload
    end

    def server_info_payload
      server = summary.server
      {
        'address' => server.address,
        'agent' => server.agent,
        'protocolVersion' => server.protocol_version
      }
    end
  end
end
