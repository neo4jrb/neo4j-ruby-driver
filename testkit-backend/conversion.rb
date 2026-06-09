module TestkitBackend
      module Conversion
        def to_testkit(object)
          case object
          when nil
            named_entity('CypherNull')
          when TrueClass, FalseClass
            value_entity('CypherBool', object)
          when Integer
            value_entity('CypherInt', object)
          when Float
            value_entity('CypherFloat', float_encode(object))
          when String
            if object.encoding == Encoding::BINARY
              value_entity('CypherBytes', object.bytes.map { |byte| "%02x" % byte }.join(' '))
            else
              value_entity('CypherString', object)
            end
          when Date
            named_entity('CypherDate', **map_of(object, :year, :month, :day))
          when Neo4j::Driver::Types::OffsetTime
            named_entity('CypherTime', hour: object.hour, minute: object.minute, second: object.second, nanosecond: object.nanosecond, 'utc_offset_s' => object.tz_offset_seconds)
          when Neo4j::Driver::Types::LocalTime
            named_entity('CypherTime', hour: object.hour, minute: object.minute, second: object.second, nanosecond: object.nanosecond)
          when Neo4j::Driver::Types::LocalDateTime
            # epoch_seconds encodes the wall clock as if it were UTC, so read
            # the components back in UTC; nanoseconds are stored exactly.
            t = object.to_time.utc
            named_entity('CypherDateTime', year: t.year, month: t.month, day: t.day, hour: t.hour,
                         minute: t.min, second: t.sec, nanosecond: object.nanoseconds)
          when Neo4j::Driver::Types::Duration
            named_entity('CypherDuration', months: object.months, days: object.days,
                         seconds: object.seconds, nanoseconds: object.nanoseconds)
          when Time
            # JRuby returns a Time whose `zone` is the TZInfo::Timezone for a
            # named zone (nil for offset-only) — `identifier` is the IANA id;
            # MRI's TimeWithZone exposes it via `time_zone.name`.
            named_entity('CypherDateTime', **map_of(object, :year, :month, :day, :hour), minute: object.min, second: object.sec, nanosecond: object.nsec, 'utc_offset_s' => object.utc_offset, 'timezone_id' => object.zone.try(:identifier) || object.try(:time_zone)&.name)
          when Symbol
            to_testkit(object.to_s)
          when Neo4j::Driver::Types::Path
            named_entity('Path', nodes: to_testkit(object.nodes), relationships: to_testkit(object.relationships))
          when Hash
            value_entity('CypherMap', object.transform_values(&method(:to_testkit)))
          when Enumerable
            value_entity('CypherList', object.map(&method(:to_testkit)))
          when Neo4j::Driver::Types::Node
            named_entity('Node', id: to_testkit(object.id), elementId: to_testkit(object.element_id),
                         labels: to_testkit(object.labels), props: to_testkit(object.properties))
          when Neo4j::Driver::Types::Relationship
            named_entity('Relationship', id: to_testkit(object.id), elementId: to_testkit(object.element_id),
                         startNodeId: to_testkit(object.start_node_id), endNodeId: to_testkit(object.end_node_id),
                         startNodeElementId: to_testkit(object.start_node_element_id),
                         endNodeElementId: to_testkit(object.end_node_element_id),
                         type: to_testkit(object.type), props: to_testkit(object.properties))
          when Java::OrgNeo4jDriverTypes::UnsupportedType
            # A value of a type newer than this driver understands; the Java
            # driver keeps its name + the bolt version that introduced it.
            named_entity('CypherUnsupportedType', name: object.name,
                         minimumProtocol: object.min_protocol_version,
                         message: object.message.or_else(nil))
          else
            raise "Not implemented #{object.class.name}:#{object.inspect}"
          end
        end

        def float_encode(f)
          case f
          when Float::NAN, -Float::INFINITY
            f.to_s
          when Float::INFINITY
            "+#{f.to_s}"
          else
            f
          end
        end

        private

        def map_of(object, *keys)
          keys.to_h { |key| [key, object.send(key)] }
        end
      end
end
