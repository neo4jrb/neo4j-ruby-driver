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
        'database' => safe { summary.database&.name },
        'query' => query_payload,
        'queryType' => safe { summary.metadata[:type] },
        'counters' => counters_payload,
        'notifications' => safe { stringify_keys_deep(summary.metadata[:notifications]) },
        'plan' => safe { stringify_keys_deep(summary.metadata[:plan]) },
        'profile' => safe { stringify_keys_deep(summary.metadata[:profile]) },
        'resultAvailableAfter' => safe { summary.result_available_after },
        'resultConsumedAfter' => safe { summary.result_consumed_after },
        'serverInfo' => server_info_payload
      }
    end

    private

    def query_payload
      query = safe { summary.query }
      {
        'text' => query&.text,
        'parameters' => encode_parameters(query&.parameters)
      }
    end

    def encode_parameters(params)
      return {} unless params.is_a?(Hash)

      params.each_with_object({}) { |(k, v), acc| acc[k.to_s] = Cypher.from_ruby(v) }
    end

    def counters_payload
      counters = safe { summary.counters }
      return {} unless counters

      payload = INTEGER_COUNTERS.each_with_object({}) do |key, acc|
        acc[Casing.camel(key)] = counters.public_send(key)
      end
      payload['containsUpdates'] = counters.contains_updates?
      payload['containsSystemUpdates'] = counters.contains_system_updates?
      payload
    end

    def server_info_payload
      server = safe { summary.server }
      {
        'address' => safe { server.address },
        'agent' => safe { server.agent },
        'protocolVersion' => safe { server.protocol_version }
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

    # Driver getters can raise on partial summaries (failure paths,
    # missing metadata). Fall back to nil rather than crashing the
    # whole response.
    def safe
      yield
    rescue StandardError
      nil
    end
  end
end
