# frozen_string_literal: true

module Neo4j
  module Driver
    class GraphDatabase
      Bolt::Lifecycle.startup

      at_exit do
        Bolt::Lifecycle.shutdown
      end

      class << self
        extend AutoClosable

        auto_closable :driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, config = {})
          raise Exceptions::AuthenticationException, 'Unsupported authentication token' unless auth_token
          config ||= Config.default_config
          # routing_settings = config.routing_settings
          # retry_settings = config.retry_settings
          routing_settings = nil
          retry_settings = nil

          Internal::DriverFactory.new.new_instance(uri, auth_token, routing_settings, retry_settings, config)
        end
      end
    end
  end
end
