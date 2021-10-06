module Testkit::Backend::Messages
  class Response
    def initialize(object)
      @object = object
    end

    def name
      self.class.name.split('::').last
    end

    def self.to_testkit(object)
      case object
      when nil
        named_entity('CypherNull')
      when TrueClass, FalseClass
        value_entity('CypherBool', object)
      when Integer
        value_entity('CypherInt', object)
      when Float
        value_entity('CypherFloat', object)
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
      when self
        object.to_testkit
      else
        raise 'Not implemented'
      end
    end

    def to_testkit
      named_entity(name, **data)
    end

    def named_entity(name, **hash)
      self.class.named_entity(name, **hash)
    end

    def self.named_entity(name, **hash)
      { name: name }.tap do |entity|
        entity[:data] = hash unless hash.empty?
      end
    end

    def value_entity(name, object)
      named_entity(name, value: object)
    end
  end
end
