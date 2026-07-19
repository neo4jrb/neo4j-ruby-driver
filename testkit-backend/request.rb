module TestkitBackend
  class Request < OpenStruct
    include Conversion
    delegate :delete, :fetch, :store, to: TestkitBackend::ObjectCache
    attr_reader :data

    def self.from(request, objects = nil)
      Requests.const_get(request[:name]).new(request[:data].transform_keys { |key| key.to_s.underscore }, objects)
    end

    def self.object_from(request)
      from(request).to_object
    end

    # Build a ClientCertificate (mutual TLS) from a testkit ClientCertificate's
    # `data` map. Flavour-agnostic: ClientCertificates.of takes path strings on
    # MRI and wraps them for the Java factory on JRuby.
    def self.client_certificate_from(cert)
      Neo4j::Driver::ClientCertificates.of(cert[:certfile], cert[:keyfile], cert[:password])
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
    rescue Neo4j::Driver::Exceptions::IllegalStateException, Neo4j::Driver::Exceptions::NoSuchRecordException,
      Neo4j::Driver::Exceptions::NoSuchRecordException, Neo4j::Driver::Exceptions::UntrustedServerException,
      ArgumentError => e
      puts e
      puts trace_for(e)
      driver_error(e)
    rescue TestkitBackend::Requests::RollbackException => e
      named_entity('FrontendError', msg: "")
    rescue StandardError => e
      puts e.inspect
      puts trace_for(e)
      named_entity('BackendError', msg: e.message)
    end

    # Java exceptions raised on JRuby don't expose Ruby's backtrace_locations;
    # fall back to backtrace (which JRuby maps from the Java stack trace).
    def trace_for(e)
      e.respond_to?(:backtrace_locations) ? e.backtrace_locations : e.backtrace
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
        entity[:data] = hash.transform_keys { |key| key.is_a?(String) ? key : key.to_s.camelize(:lower) } unless hash.empty?
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
