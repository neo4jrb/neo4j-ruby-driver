# frozen_string_literal: true

module TestkitBackend
  # Builds the testkit Summary `data` payload from a driver
  # Summary::ResultSummary. Uses the public Summary API for fields
  # with a clean Java-shaped accessor (counters, server, query,
  # database, timings); reaches into the private `metadata` escape
  # hatch for fields where testkit asserts wire-format faithfulness:
  #   - queryType: nil when the server didn't send `:type` (the public
  #     API defaults to READ_ONLY, which loses that distinction).
  #   - notifications: 4.x sends `severity`, 5.x sends `severityLevel`
  #     + `category`. Tests assert against the as-shipped key.
  #   - plan / profile: include implementation-specific extras like
  #     `pageCacheMisses`, `pageCacheHitRatio`, `time` that the public
  #     Plan/ProfiledPlan API doesn't expose.
  class SummaryPayload < Data.define(:summary)
    INTEGER_COUNTERS = %i[
      nodes_created nodes_deleted relationships_created relationships_deleted
      properties_set labels_added labels_removed indexes_added indexes_removed
      constraints_added constraints_removed system_updates
    ].freeze

    def to_h
      meta = wire_metadata
      {
        'database' => summary.database&.name,
        'query' => query_payload,
        'queryType' => meta[:type],
        'counters' => counters_payload,
        'notifications' => stringify_keys_deep(meta[:notifications]),
        'plan' => stringify_keys_deep(meta[:plan]),
        'profile' => stringify_keys_deep(meta[:profile]),
        'resultAvailableAfter' => summary.result_available_after,
        'resultConsumedAfter' => summary.result_consumed_after,
        'serverInfo' => server_info_payload
      }
    end

    private

    # ResultSummary#metadata is private (Java's ResultSummary doesn't
    # expose raw wire metadata at all). On MRI the accessor exists for
    # exactly this kind of internal consumer; on JRuby the underlying
    # Java summary has no equivalent, so we degrade to an empty hash
    # — the JRuby flavor has no baseline expectations on the wire-
    # faithful fields and produces nil entries here, which matches the
    # status quo.
    def wire_metadata
      summary.respond_to?(:metadata, true) ? summary.send(:metadata) : {}
    end

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

    def stringify_keys_deep(value)
      case value
      when Hash  then value.transform_keys(&:to_s).transform_values { stringify_keys_deep(it) }
      when Array then value.map { stringify_keys_deep(it) }
      else value
      end
    end
  end
end
