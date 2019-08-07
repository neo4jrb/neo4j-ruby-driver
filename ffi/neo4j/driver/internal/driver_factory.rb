# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class DriverFactory
        def new_instance(uri, auth_token, routing_settings, retry_settings, config)
          connector = create_connector(uri, auth_token)
          create_driver(uri, connector).tap(&:verify_connectivity)
        end

        private

        def create_connector(uri, auth_token)
          uri = URI(uri)
          address = Bolt::Address.create(uri.host, uri.port.to_s)
          config = Bolt::Config.create
          Bolt::Config.set_user_agent(config, 'seabolt-cmake/1.7')
          Bolt::Connector.create(address, auth_token, config)
        end

        def create_driver(uri, connector)
          create_direct_driver(connector)
        end

        def create_direct_driver(connector)
          connection_provider = DirectConnectionProvider.new(connector)
          session_factory = create_session_factory(connection_provider)
          InternalDriver.new(session_factory)
        end

        def create_session_factory(connection_provider, retry_logic = nil, config = nil)
          SessionFactoryImpl.new(connection_provider, retry_logic, config)
        end
      end
    end
  end
end
