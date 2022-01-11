module Neo4j::Driver
  module Internal
    module Util
      # Utility class for extracting data.
      class Extract
        def initialize
          raise java.lang.UnsupportedOperationException
        end

        class << self
          def list(data, map_function)
            size = data.length

            case size
            when 0
              java.util.Collections.empty_list
            when 1
              java.util.Collections.singleton_list(map_function.apply(data.first))
            else
              result = []
              data.each do |value|
                result << map_function.apply(value)
              end

              result.freeze
            end
          end

          def map(record, map_function)
            size = record.length

            case size
            when 0
              java.util.Collections.empty_map
            when 1
              java.util.Collections.singleton_map[record.keys.first] = map_function.apply(record.first)
            else
              map = {}
              keys = record.keys
              size.times do |i|
                map[keys[i]] = map_function.apply(record[i])
              end

              map.freeze
            end
          end

          def properties(map, map_function)
            size = map.length

            case size
            when 0
              java.util.Collections.empty_list
            when 1
              key = map.keys.first
              value = map[key]
              java.util.Collections.singleton_list(InternalPair.of(key, map_function.apply(value)))
            else
              list = []
              keys = record.keys
              map.keys.each do |map_key|
                map_value = map[map_key]
                list << InternalPair.of(map_key, map_function.apply(map_value))
              end

              list.freeze
            end
          end

          def fields(map, map_function)
            size = map.keys.length

            case size
            when 0
              java.util.Collections.empty_list
            when 1
              key = map.keys.first
              value = map[key]
              java.util.Collections.singleton_list(InternalPair.of(key, map_function.apply(value)))
            else
              list = []
              keys = record.keys
              size.times do |i|
                key = keys[i]
                value = map[key]
                list << InternalPair.of(key, map_function.apply(value))
              end

              list.freeze
            end
          end

          def map_of_values(map)
            return java.util.Collections.empty_map if map.nil? || map.empty?

            result = {}

            map.entry_set.each do |key, value|
              assert_parameter(value)
              result[key] = value
            end

            result
          end

          def assert_parameter(value)
            if value.instance_of? Types::Node
              raise Exceptions::ClientException, "Nodes can't be used as parameters."
            end

            if value.instance_of? Types::Relationship
              raise Exceptions::ClientException, "Relationships can't be used as parameters."
            end

            if value.instance_of? Types::Path
              raise Exceptions::ClientException, "Paths can't be used as parameters."
            end
          end
        end
      end
    end
  end
end
