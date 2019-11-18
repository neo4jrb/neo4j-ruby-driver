# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class DriverFactory
        BOLT_URI_SCHEME = 'bolt'
        BOLT_ROUTING_URI_SCHEME = 'bolt+routing'
        NEO4J_URI_SCHEME = 'neo4j'
        DEFAULT_PORT = 7687

        def new_instance(uri, auth_token, routing_settings, retry_settings, config)
          uri = URI(uri)
          connector = create_connector(uri, auth_token)
          create_driver(uri.scheme, connector, routing_settings).tap(&:verify_connectivity)
        end

        private

        def create_connector(uri, auth_token)
          address = Bolt::Address.create(host(uri).gsub(/^\[(.*)\]$/, '\\1'), port(uri).to_s)
          config = Bolt::Config.create
          Bolt::Config.set_user_agent(config, 'seabolt-cmake/1.7')
          Bolt::Connector.create(address, auth_token, config)
        end

        def host(uri)
          uri.host.tap { |host| raise ArgumentError, "Invalid address format `#{uri}`" unless host }
        end

        def port(uri)
          uri.port&.tap {|port| raise ArgumentError, "Illegal port:  #{port}" unless (0..65_535).cover?(port) } ||
            DEFAULT_PORT
        end

        def create_driver(scheme, connector, routing_settings)
          case scheme
          when BOLT_URI_SCHEME
            # assert_no_routing_context( uri, routing_settings )
            # return createDirectDriver( securityPlan, address, connectionPool, retryLogic, metrics, config );
            create_direct_driver(connector)
          when BOLT_ROUTING_URI_SCHEME, NEO4J_URI_SCHEME
            # create_routing_driver( security_plan, address, connection_ool, eventExecutorGroup, routingSettings, retryLogic, metrics, config );
          else
            raise Exceptions::ClientException, "Unsupported URI scheme: #{scheme}"
          end
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
