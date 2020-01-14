# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class DriverFactory
        include ErrorHandling
        BOLT_URI_SCHEME = 'bolt'
        BOLT_ROUTING_URI_SCHEME = 'bolt+routing'
        NEO4J_URI_SCHEME = 'neo4j'
        DEFAULT_PORT = 7687

        def new_instance(uri, auth_token, config)
          uri = URI(uri)
          routing_context = routing_context(uri)
          connector, logger, resolver = create_connector(uri, auth_token, routing_context, config)
          retry_logic = Retry::ExponentialBackoffRetryLogic.new(config[:max_transaction_retry_time], config[:logger])
          create_driver(connector, logger, resolver, retry_logic, config).tap(&:verify_connectivity)
        end

        private

        def create_connector(uri, auth_token, routing_context, config)
          address = Bolt::Address.create(host(uri).gsub(/^\[(.*)\]$/, '\\1'), port(uri).to_s)
          bolt_config = bolt_config(config)
          logger = InternalLogger.register(bolt_config, config[:logger])
          set_socket_options(bolt_config, config)
          set_routing_context(bolt_config, routing_context)
          set_scheme(bolt_config, uri, routing_context)
          resolver = InternalResolver.register(bolt_config, config[:resolver])
          [Bolt::Connector.create(address, auth_token, bolt_config), logger, resolver]
        end

        def bolt_config(config)
          bolt_config = Bolt::Config.create
          config.each do |key, value|
            case key
            when :max_connection_pool_size
              check_error Bolt::Config.set_max_pool_size(bolt_config, value)
            when :max_connection_life_time
              check_error Bolt::Config.set_max_connection_life_time(bolt_config, DurationNormalizer.milliseconds(value))
            when :connection_acquisition_timeout
              check_error Bolt::Config.set_max_connection_acquisition_time(bolt_config,
                                                                           DurationNormalizer.milliseconds(value))
            when :encryption
              check_error Bolt::Config.set_transport(
                bolt_config,
                value ? Bolt::Config::BOLT_TRANSPORT_ENCRYPTED : Bolt::Config::BOLT_TRANSPORT_PLAINTEXT
              )
            end
          end
          check_error Bolt::Config.set_user_agent(bolt_config, 'seabolt-cmake/1.7')
          bolt_config
        end

        def set_socket_options(bolt_config, config)
          socket_options = nil
          config.each do |key, value|
            case key
            when :connection_timeout
              check_error Bolt::SocketOptions.set_connect_timeout(socket_options ||= Bolt::SocketOptions.create,
                                                                  DurationNormalizer.milliseconds(value))
            end
          end
          check_error Bolt::Config.set_socket_options(bolt_config, socket_options) if socket_options
        end

        def routing_context(uri)
          query = uri.query
          return if query.blank?
          URI.decode_www_form(query).to_h
        end

        def set_routing_context(bolt_config, routing_context)
          value = Bolt::Value.create
          check_error Bolt::Config.set_routing_context(bolt_config, Value::ValueAdapter.to_neo(value, routing_context))
        end

        def host(uri)
          uri.host.tap { |host| raise ArgumentError, "Invalid address format `#{uri}`" unless host }
        end

        def port(uri)
          uri.port&.tap { |port| raise ArgumentError, "Illegal port:  #{port}" unless (0..65_535).cover?(port) } ||
            DEFAULT_PORT
        end

        def set_scheme(bolt_config, uri, routing_context)
          check_error Bolt::Config.set_scheme(bolt_config, scheme(uri, routing_context))
        end

        def scheme(uri, routing_context)
          scheme = uri.scheme
          case scheme
          when BOLT_URI_SCHEME
            assert_no_routing_context(uri, routing_context)
            Bolt::Config::BOLT_SCHEME_DIRECT
          when BOLT_ROUTING_URI_SCHEME, NEO4J_URI_SCHEME
            Bolt::Config::BOLT_SCHEME_NEO4J
          else
            raise Exceptions::ClientException, "Unsupported URI scheme: #{scheme}"
          end
        end

        def assert_no_routing_context(uri, routing_context)
          if routing_context
            raise ArgumentError, "Routing parameters are not supported with scheme 'bolt'. Given URI: '#{uri}'"
          end
        end

        def create_driver(connector, logger, resolver, retry_logic, config)
          connection_provider = DirectConnectionProvider.new(connector, config)
          session_factory = create_session_factory(connection_provider, retry_logic, config)
          InternalDriver.new(session_factory, logger, resolver)
        end

        def create_session_factory(connection_provider, retry_logic = nil, config = nil)
          SessionFactoryImpl.new(connection_provider, retry_logic, config)
        end
      end
    end
  end
end
