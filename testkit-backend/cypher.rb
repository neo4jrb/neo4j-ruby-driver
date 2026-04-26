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
      else
        # Graph types / temporals we don't yet support — stringify so tests
        # at least fail with a visible mismatch rather than a JSON error.
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
  end
end
