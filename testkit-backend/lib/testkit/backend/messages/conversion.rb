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
          when String
            if object.encoding == Encoding::BINARY
              value_entity('CypherBytes', object.bytes.map { |byte| "%02x" % byte }.join(' '))
            else
              value_entity('CypherString', object)
            end
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
      end
    end
  end
end
