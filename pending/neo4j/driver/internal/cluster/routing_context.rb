module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingContext
        include Scheme

        EMPTY = new
        ROUTING_ADDRESS_KEY = 'address'

        def initialize(uri = nil)
          if uri
            @server_routing_enabled = routing_scheme?(uri.scheme)
            @context = parse_parameters(uri).freeze
          else
            @server_routing_enabled = true
            @context = {}
          end
        end

        def defined?
          @context.size > 1
        end

        def to_h
          @context
        end

        def server_routing_enabled?
          @server_routing_enabled
        end

        def to_s
          "RoutingContext #{@context} ServerRoutingEnabled=#{@server_routing_enabled}"
        end

        private

        def parse_parameters(uri)
          query = uri.query
          address = "#{uri.host}:#{uri.port || BoltServerAddress::DEFAULT_PORT}"
          parameters = { ROUTING_ADDRESS_KEY => address }
          return parameters if query.blank?

          pairs = query.split('&')
          pairs.each do |pair|
            key_value = pair.split('=')

            if key_value.size != 2
              raise Exceptions::IllegalArgumentException, "Invalid parameters: '#{pair}' in URI '#{uri}'"
            end

            key = trim_and_verify_key(key_value[0], 'key', uri)
            if parameters.key?(key)
              raise ArgumentError, "Duplicated query parameters with key '#{key}' in URI '#{uri}'"
            end
            parameters[key] = trim_and_verify(key_value[1], 'value', uri)
          end

          parameters
        end

        def trim_and_verify_key(s, key, uri)
          trim_and_verify(s, key, uri).tap do |trimmed|
            if trimmed == ROUTING_ADDRESS_KEY
              raise Exceptions::IllegalArgumentException, "The key 'address' is reserved for routing context."
            end
          end
        end

        def trim_and_verify(string, name, uri)
          string.strip.tap do |result|
            raise ArgumentError, "Illegal empty #{name} in URI query '#{uri}'" if result.empty?
          end
        end
      end
    end
  end
end
