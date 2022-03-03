module Testkit::Backend::Messages
  class Request < OpenStruct
    include Conversion
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
      store(e)
      named_entity('DriverError', id: e.object_id, errorType: e.class.name, msg: e.message, code: e.code)
    rescue Neo4j::Driver::Exceptions::IllegalStateException, Neo4j::Driver::Exceptions::NoSuchRecordException, ArgumentError => e
      puts e
      puts e.backtrace_locations
      store(e)
      named_entity('DriverError', id: e.object_id, errorType: e.class.name, msg: e.message)
    rescue Testkit::Backend::Messages::Requests::RollbackException => e
      named_entity('FrontendError', msg: "")
    rescue StandardError => e
      puts e.inspect
      puts e.backtrace_locations
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

    def timeout_duration(field = @table[:timeout])
      field&.*(1e-3.seconds)
    end
  end
end