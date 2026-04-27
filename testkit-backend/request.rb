# frozen_string_literal: true

module TestkitBackend
  # Mixin for testkit request types.
  #
  # A concrete request is a `Data.define(...)` subclass listing only the
  # data fields it consumes — the registry is threaded through transparently
  # so it never appears in the field declaration:
  #
  #   class TransactionCommit < Data.define(:tx_id)
  #     include Request
  #
  #     def execute
  #       registry.take(tx_id).commit
  #       Response::Transaction.new(id: tx_id)
  #     end
  #   end
  #
  # Field names are snake_case in Ruby; `from_json` maps them to
  # camelCase JSON keys automatically.
  module Request
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def from_json(data, registry, connection)
        kwargs = members.each_with_object(registry: registry, connection: connection) do |name, acc|
          acc[name] = data[Casing.camel(name)]
        end
        new(**kwargs)
      end
    end

    attr_reader :registry, :connection

    def initialize(registry:, connection:, **fields)
      @registry = registry
      @connection = connection
      super(**fields)
    end

    # Run the request and translate exceptions into the appropriate
    # error response. Concrete subclasses implement `#execute`.
    def safely_execute
      execute
    rescue Neo4j::Driver::Exceptions::Neo4jException => e
      Response::DriverError.from(e, registry: registry)
    rescue ClientGeneratedError, Registry::UnknownHandle, ArgumentError => e
      Response::FrontendError.new(msg: "#{e.class}: #{e.message}")
    rescue StandardError => e
      warn "[backend] #{e.class}: #{e.message}\n  #{e.backtrace.first(5).join("\n  ")}"
      Response::BackendError.new(msg: "#{e.class}: #{e.message}")
    end

    # Translate testkit's tx_meta dict + millisecond timeout into the
    # {metadata:, timeout:} kwargs accepted by the driver's
    # begin_transaction / execute_read / execute_write. Used by both
    # the explicit and managed transaction handlers.
    def tx_options(tx_meta, timeout_ms)
      {
        metadata: Cypher.decode_value_map(tx_meta),
        timeout: timeout_ms && timeout_ms / 1000.0
      }.compact
    end

    def self.dispatch(request_json, registry, connection)
      name = request_json['name'].to_s
      klass = lookup(name)
      return Response::UnknownType.new(message: "No handler for request #{name}") unless klass

      klass.from_json(request_json['data'] || {}, registry, connection).safely_execute
    end

    def self.lookup(name)
      klass = Requests.const_get(name, false)
      klass if klass.is_a?(Class) && klass.include?(Request)
    rescue NameError
      nil
    end
  end
end
