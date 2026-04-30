# frozen_string_literal: true

module TestkitBackend
  # Builds the testkit Summary `data` payload from a driver Summary.
  #
  # Lives separately because the Summary payload is the most complex
  # cross-protocol mapping in the backend — pulling it out of the
  # request handlers keeps each request method short and readable.
  class SummaryPayload < Data.define(:summary)
    INTEGER_COUNTERS = %i[
      nodes_created nodes_deleted relationships_created relationships_deleted
      properties_set labels_added labels_removed indexes_added indexes_removed
      constraints_added constraints_removed system_updates
    ].freeze

    def to_h
      {
        'database' => summary.database&.name,
        'query' => query_payload,
        'queryType' => summary.metadata[:type],
        'counters' => counters_payload,
        'notifications' => stringify_keys_deep(summary.metadata[:notifications]),
        'plan' => stringify_keys_deep(summary.metadata[:plan]),
        'profile' => stringify_keys_deep(summary.metadata[:profile]),
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

      params.each_with_object({}) { |(k, v), acc| acc[k.to_s] = Cypher.from_ruby(v) }
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

    # Plan / profile / notifications come back from the server as nested
    # maps with symbol keys (the unpacker symbolises). Testkit only
    # checks they're dicts/lists; passing the raw structure with string
    # keys is the simplest faithful representation.
    def stringify_keys_deep(value)
      case value
      when Hash  then value.each_with_object({}) { |(k, v), acc| acc[k.to_s] = stringify_keys_deep(v) }
      when Array then value.map { stringify_keys_deep(it) }
      else value
      end
    end
  end
end
