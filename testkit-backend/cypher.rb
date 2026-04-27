# frozen_string_literal: true

module TestkitBackend
  # Conversion between testkit's tagged JSON value format
  # ({"name": "CypherInt", "data": {"value": ...}}) and native Ruby values.
  #
  # Incoming: Cypher.to_ruby(tagged_json_hash) -> Ruby value
  #           Cypher.decode_value_map(hash) -> hash with symbol keys + decoded values
  # Outgoing: Cypher.from_ruby(ruby_value) -> tagged JSON hash
  module Cypher
    module_function

    # Decode a {"key" => tagged_value, ...} JSON map into a {key: ruby_value, ...}
    # Ruby hash. Used for query parameters and tx_metadata where each value is
    # itself a tagged Cypher value but the outer keys are plain JSON strings.
    def decode_value_map(value)
      return {} unless value.is_a?(Hash)

      value.transform_keys(&:to_sym).transform_values(&method(:to_ruby))
    end

    def to_ruby(value)
      return value unless value.is_a?(Hash) && value.key?('name')

      data = value['data'] || {}
      inner = data['value']

      case value['name']
      when 'CypherNull'    then nil
      when 'CypherBool'    then inner
      when 'CypherInt'     then inner
      when 'CypherFloat'   then parse_float(inner)
      when 'CypherString'  then inner
      when 'CypherBytes'   then decode_bytes(inner)
      when 'CypherList'    then inner.map { |v| to_ruby(v) }
      when 'CypherMap'     then inner.transform_values { |v| to_ruby(v) }
      when 'CypherDate'    then ::Date.new(data['year'], data['month'], data['day'])
      when 'CypherDateTime' then build_datetime(data)
      else
        # Unknown tag — return raw so the driver call can fail loudly.
        value
      end
    end

    def from_ruby(value)
      case value
      when nil              then tagged('CypherNull')
      when true, false      then tagged('CypherBool', value)
      when Integer          then tagged('CypherInt', value)
      when Float            then tagged('CypherFloat', float_to_wire(value))
      when String           then encode_string(value)
      when Array            then tagged('CypherList', value.map { |v| from_ruby(v) })
      when Hash             then tagged('CypherMap', value.transform_values { |v| from_ruby(v) })
      when ::Date           then date_to_tagged(value)
      when ::Time, ::DateTime then time_to_tagged(value)
      when Neo4j::Driver::Types::Node         then node_to_tagged(value)
      when Neo4j::Driver::Types::Relationship then relationship_to_tagged(value)
      when Neo4j::Driver::Types::Path         then path_to_tagged(value)
      else
        # Anything we don't yet handle — stringify so tests fail with a
        # visible mismatch rather than a JSON error.
        tagged('CypherString', value.to_s)
      end
    end

    def tagged(name, value = nil)
      data = value.nil? && name == 'CypherNull' ? {} : { 'value' => value }
      { 'name' => name, 'data' => data }
    end

    def parse_float(value)
      case value
      when '+Infinity' then Float::INFINITY
      when '-Infinity' then -Float::INFINITY
      when 'NaN'       then Float::NAN
      else Float(value)
      end
    end

    def float_to_wire(value)
      return '+Infinity' if value.infinite? == 1
      return '-Infinity' if value.infinite? == -1
      return 'NaN' if value.nan?

      value
    end

    def decode_bytes(value)
      # Testkit serialises byte arrays as a space-separated string of hex bytes.
      return value if value.is_a?(String) && value.encoding == Encoding::BINARY

      value.to_s.split(/\s+/).map { |b| b.to_i(16) }.pack('C*').force_encoding(Encoding::BINARY)
    end

    def encode_string(value)
      if value.encoding == Encoding::BINARY
        hex = value.each_byte.map { |b| b.to_s(16).rjust(2, '0') }.join(' ')
        tagged('CypherBytes', hex)
      else
        tagged('CypherString', value)
      end
    end

    def build_datetime(data)
      ::Time.new(data['year'], data['month'], data['day'],
                 data['hour'], data['minute'], data['second'] + data['nanosecond'] / 1_000_000_000.0,
                 data['utc_offset_s'] || 0)
    end

    def date_to_tagged(value)
      { 'name' => 'CypherDate',
        'data' => { 'year' => value.year, 'month' => value.month, 'day' => value.day } }
    end

    def time_to_tagged(value)
      value = value.to_time if value.is_a?(::DateTime)
      { 'name' => 'CypherDateTime',
        'data' => {
          'year' => value.year,
          'month' => value.month,
          'day' => value.day,
          'hour' => value.hour,
          'minute' => value.min,
          'second' => value.sec,
          'nanosecond' => value.nsec,
          'utc_offset_s' => value.utc_offset,
          'timezone_id' => value.respond_to?(:time_zone) ? value.time_zone&.name : nil
        } }
    end

    # Inner field values (labels, props, ids) are themselves tagged
    # Cypher values — labels round-trip as CypherList<CypherString>,
    # props as CypherMap<CypherX>, ids as CypherInt — so we feed them
    # through from_ruby rather than building plain JSON. elementId is
    # the only field testkit expects as a bare string.
    def node_to_tagged(node)
      { 'name' => 'CypherNode',
        'data' => {
          'id' => from_ruby(node.id),
          'labels' => from_ruby(node.labels.map(&:to_s)),
          'props' => from_ruby(stringify_keys(node.properties)),
          'elementId' => node.element_id
        } }
    end

    def relationship_to_tagged(rel)
      { 'name' => 'CypherRelationship',
        'data' => {
          'id' => from_ruby(rel.id),
          'startNodeId' => from_ruby(rel.start_node_id),
          'endNodeId' => from_ruby(rel.end_node_id),
          'type' => from_ruby(rel.type.to_s),
          'props' => from_ruby(stringify_keys(rel.properties)),
          'elementId' => rel.element_id,
          # Driver doesn't yet model start/end element ids separately;
          # fall back to the stringified integer ids the way our own
          # Types::Node default does for elementId.
          'startNodeElementId' => rel.start_node_id.to_s,
          'endNodeElementId' => rel.end_node_id.to_s
        } }
    end

    def path_to_tagged(path)
      { 'name' => 'CypherPath',
        'data' => {
          'nodes' => from_ruby(path.nodes),
          'relationships' => from_ruby(path.relationships)
        } }
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
    end
  end
end
