module Testkit
  module Backend
    module Messages
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
          when Neo4j::Driver::Types::Bytes
            value_entity('CypherBytes', object.bytes.map { |byte| "%02x" % byte }.join(' '))
          when String
            value_entity('CypherString', object)
          when Symbol
            to_testkit(object.to_s)
          when Hash
            value_entity('CypherMap', object.transform_values(&method(:to_testkit)))
          when Neo4j::Driver::Types::Path
            raise 'Not implemented'
          when Enumerable
            value_entity('CypherList', object.map(&method(:to_testkit)))
          when Neo4j::Driver::Types::Node
            named_entity('Node', id: to_testkit(object.id), labels: to_testkit(object.labels), props: to_testkit(object.properties))
          else
            raise 'Not implemented'
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
      end
    end
  end
end
