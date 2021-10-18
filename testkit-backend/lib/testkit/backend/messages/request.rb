module Testkit::Backend::Messages
  class Request < OpenStruct
    delegate :delete, :fetch, :store, to: :@command_processor
    attr_reader :data

    def self.from(request, objects = nil)
      Requests.const_get(request[:name]).new(request[:data], objects)
    end

    def self.object_from(request)
      from(request).to_object
    end

    def initialize(hash, command_processor)
      @data = hash
      @command_processor = command_processor
      super(hash)
    end

    def process_request
      process
    rescue Neo4j::Driver::Exceptions::Neo4jException => e
      # puts e
      named_entity('DriverError', id: e.object_id, errorType: e.class.name, msg: e.message, code: e.code)
    rescue Neo4j::Driver::Exceptions::IllegalStateException, ArgumentError => e
      # puts e
      named_entity('DriverError', id: e.object_id, errorType: e.class.name, msg: e.message)
    rescue StandardError => e
      # puts e
      named_entity('BackendError', msg: e.message)
    end

    def process
      # name, data = %i[name data].map(&response.method(:send))
      # named_entity(name, **data)
      response.to_testkit
    end

    private

    def to_params
      params&.transform_values(&Request.method(:object_from)) || {}
    end

    def reference(name)
      named_entity(name, id: store(to_object))
    end

    def named_entity(name, **hash)
      { name: name }.tap do |entity|
        entity[:data] = hash unless hash.empty?
      end
    end

    def value_entity(name, object)
      named_entity(name, value: object)
    end

    def to_testkit(object)
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
      else
        raise 'Not implemented'
      end
    end

    def timeout_duration(field=@table[:timeout])
      field&.*(1e-3.seconds)
    end
  end
end