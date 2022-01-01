module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingContext
        EMPTY = new
        ROUTING_ADDRESS_KEY = 'address'

        attr_reader :context, :server_routing_enabled

        def initialize(uri = nil)
          if uri.nil?
            @server_routing_enabled = true
            @context = []
          else
            @server_routing_enabled = Scheme.routing_scheme?(uri.scheme)
            @context = parse_parameters(uri).freeze
          end
        end

        def defined?
          context.size > 1
        end

        def to_s
          "RoutingContext #{context} ServerRoutingEnabled=#{server_routing_enabled}"
        end

        private

        def parse_parameters(uri)
          query = uri.query

          address = if uri.port == -1
                      "#{uri.host}:#{BoltServerAddress::DEFAULT_PORT}"
                    else
                      "#{uri.host}:#{uri.port}"
                    end

          parameters = {}
          parameters[ROUTING_ADDRESS_KEY] = address

          return parameters if query.nil? || query.empty?

          pairs = query.split('&')

          pairs.each do |pair|
            key_value = query.split('=')

            if key_value != 2
              raise Exceptions::IllegalArgumentException, "Invalid parameters: '#{pair}' in URI '#{uri}'"
            end

            previous_value = parameters[trim_and_verify_key(key_value[0], 'key', uri)] = trim_and_verify(key_value[1], 'value', uri)

            if !previous_value.nil?
              raise Exceptions::IllegalArgumentException, "Duplicated query parameters with key '#{previous_value}' in URI '#{uri}'"
            end
          end

          parameters
        end

        def trim_and_verify_key(s, key, uri)
          trimmed = trim_and_verify(s, key, uri)

          if trimmed.eql?(ROUTING_ADDRESS_KEY)
            raise Exceptions::IllegalArgumentException, "The key 'address' is reserved for routing context."
          end

          trimmed
        end

        def trim_and_verify(string, name, uri)
          result = string.trim

          if result.empty?
            raise Exceptions::IllegalArgumentException, "Illegal empty #{name} in URI query '#{uri}'"
          end

          result
        end
      end
    end
  end
end
