module Testkit::Backend::Messages
  class Request < OpenStruct
    include Conversion
    delegate :delete, :fetch, :store, to: Testkit::Backend::ObjectCache
    attr_reader :data

    def self.from(request, objects = nil)
      Requests.const_get(request[:name]).new(request[:data].transform_keys{|key| key.to_s.underscore}, objects)
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
      driver_error(e)
    rescue Neo4j::Driver::Exceptions::IllegalStateException, Neo4j::Driver::Exceptions::NoSuchRecordException, ArgumentError => e
      puts e
      puts e.backtrace_locations
      driver_error(e)
    rescue Testkit::Backend::Messages::Requests::RollbackException => e
      named_entity('FrontendError', msg: "")
    rescue StandardError => e
      puts e.inspect
      puts e.backtrace_locations
      named_entity('BackendError', msg: e.message)
    end

    def process
      response.to_testkit
    end

    private

    def driver_error(e)
      Responses::DriverError.new(e).to_testkit
    end

    def decode(request)
      request&.transform_values(&Request.method(:object_from)) || {}
    end

    def reference(name)
      named_entity(name, id: store(to_object))
    end

    def named_entity(name, **hash)
      { name: name }.tap do |entity|
        entity[:data] = hash.transform_keys{|key| key.to_s.camelize(:lower)} unless hash.empty?
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
