# frozen_string_literal: true

module TestkitBackend
  # Builds the testkit Summary `data` payload from a driver
  # Summary::ResultSummary using only public Summary API. All
  # protocol-shaped serialisation (camelCase keys, wire query-type
  # tokens, Notification/Plan/Profile dict layouts) lives here, not
  # on the driver.
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
        'notifications' => (notifications.empty? ? nil : notifications.map(&method(:notification_dict))),
        'plan' => plan_dict(summary.plan),
        'profile' => profile_dict(summary.profile),
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

    def notification_dict(notification)
      {
        'code' => notification.code,
        'title' => notification.title,
        'description' => notification.description,
        'severityLevel' => notification.severity_level&.to_s,
        'category' => notification.category&.to_s,
        'position' => position_dict(notification.position)
      }.compact
    end

    def position_dict(position)
      return nil unless position

      { 'offset' => position.offset, 'line' => position.line, 'column' => position.column }
    end

    def plan_dict(plan)
      return nil unless plan

      {
        'operatorType' => plan.operator_type,
        'identifiers' => plan.identifiers.to_a,
        'args' => plan_args(plan),
        'children' => plan.children.map(&method(:plan_dict))
      }
    end

    def profile_dict(profile)
      return nil unless profile

      plan_dict(profile).merge(
        'dbHits' => profile.db_hits,
        'rows' => profile.records,
        'children' => profile.children.map(&method(:profile_dict))
      )
    end

    # JRuby's `arguments` returns a Java Map<String, Value>; the Ext
    # module exposes a Ruby-idiomatic `args` (Map → Hash, Value →
    # ruby_object). MRI's `arguments` is already a primitive-valued
    # Ruby hash. Either way, normalise keys to strings for the wire.
    def plan_args(plan)
      raw = plan.respond_to?(:args) ? plan.args : plan.arguments
      raw.transform_keys(&:to_s)
    end
  end
end
