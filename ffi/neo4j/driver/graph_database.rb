# frozen_string_literal: true

module Neo4j
  module Driver
    class GraphDatabase
      VALID_ROUTING_SCHEMES =
        [Internal::DriverFactory::BOLT_ROUTING_URI_SCHEME, Internal::DriverFactory::NEO4J_URI_SCHEME]

      Bolt::Lifecycle.startup

      at_exit do
        Bolt::Lifecycle.shutdown
      end

      class << self
        extend AutoClosable

        auto_closable :driver, :routing_driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, config = nil)
          unless auth_token.is_a? FFI::Pointer
            raise Exceptions::AuthenticationException, 'Unsupported authentication token'
          end
          config ||= Config.default_config

          Internal::DriverFactory.new.new_instance(uri, auth_token, config)
        end

        def routing_driver(routing_uris, auth_toke, config)
          assert_routing_uris(routing_uris)

          routing_uris.each do |uri|
            return driver(uri, auth_toke, config)
          rescue Exceptions::ServiceUnavailableException => e
            #log.warn("Unable to create routing driver for URI: #{uri}", e)
          end

          raise Exceptions::ServiceUnavailableException, 'Failed to discover an available server'
        end

        private

        def assert_routing_uris(uris)
          scheme = (uris.map(&method(:URI)).map(&:scheme) - VALID_ROUTING_SCHEMES).first
          return unless scheme
          raise ArgumentError,
                "Illegal URI scheme, expected URI scheme '#{scheme}' to be among [#{VALID_ROUTING_SCHEMES.join ', '}]"
        end
      end
    end
  end
end
