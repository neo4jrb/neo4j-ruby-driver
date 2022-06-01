module Neo4j::Driver::Internal
  class DriverFactory
    include Scheme
    NO_ROUTING_CONTEXT_ERROR_MESSAGE = "Routing parameters are not supported with scheme 'bolt'. Given URI: "

    def initialize(domain_name_resolver = ->(name) { [name] })
      @domain_name_resolver = domain_name_resolver
    end

    def new_instance(uri, auth_token, routing_settings, retry_settings, config, security_plan, event_loop_group = nil)
      bootstrap = create_bootstrap(
        **event_loop_group ? { event_loop_group: event_loop_group } : { thread_count: config[:event_loop_threads] }
      )

      address = BoltServerAddress.new(uri: uri)
      new_routing_settings = routing_settings.with_routing_context(Cluster::RoutingContext.new(uri))

      # org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.InternalLoggerFactory.setDefaultFactory(org.neo4j.driver.internal.logging.NettyLogging.new(config.logging))
      _event_executor_group = nil #bootstrap.group
      retry_logic = Retry::ExponentialBackoffRetryLogic.new(retry_settings, _event_executor_group, config[:logger])

      metrics_provider = create_driver_metrics(config)
      connection_pool = create_connection_pool(auth_token, security_plan, bootstrap, metrics_provider, config,
                                               event_loop_group.nil?, new_routing_settings.routing_context)

      create_driver(uri, security_plan, address, connection_pool, _event_executor_group, new_routing_settings, retry_logic, metrics_provider, config)
    end

    private

    def create_connection_pool(auth_token, security_plan, bootstrap, metrics_provider, config, owns_event_loop_group, routing_context)
      clock = Util::Clock::System
      settings = ConnectionSettings.new(auth_token, config[:user_agent], config[:connection_timeout].in_milliseconds)
      connector = create_connector(settings, security_plan, config, clock, routing_context)
      pool_settings = Async::Pool::PoolSettings.new(
        config[:max_connection_pool_size],
        config[:connection_acquisition_timeout].in_milliseconds,
        config[:max_connection_lifetime].in_milliseconds,
        config[:idle_time_before_connection_test]&.in_milliseconds || -1 # TODO: remember to get rid of -1
      )
      Async::Pool::ConnectionPoolImpl.new(connector, pool_settings, config[:logger])
    end

    def create_driver_metrics(config)
      if config[:metrics_enabled]
        Metrics::InternalMetricsProvider.new(config[:logger])
      else
        Metrics::MetricsProvider::METRICS_DISABLED_PROVIDER
      end
    end

    def create_resolver(config)
      config[:resolver] || ->(address) { [address] }
    end

    def assert_no_routing_context(uri, routing_settings)
      routing_context = routing_settings.routing_context
      if routing_context.defined?
        raise ArgumentError, "Routing parameters are not supported with scheme 'bolt'. Given URI: '#{uri}'"
      end
    end

    def create_connector(settings, security_plan, config, clock, routing_context)
      Async::Connection::ChannelConnectorImpl.new(
        settings, security_plan, config[:logger], clock, routing_context, &method(:domain_name_resolver))
    end

    def create_driver(uri, security_plan, address, connection_pool, eventExecutorGroup, routing_settings, retryLogic, metricsProvider, config)
      if routing_scheme?(uri.scheme.downcase)
        createRoutingDriver(security_plan, address, connection_pool, eventExecutorGroup, routing_settings, retryLogic, metricsProvider, config)
      else
        assert_no_routing_context(uri, routing_settings)
        createDirectDriver(security_plan, address, connection_pool, retryLogic, metricsProvider, config)
      end
    rescue => driver_error
      # we need to close the connection pool if driver creation threw exception
      closeConnectionPoolAndSuppressError(connection_pool, driver_error)
      raise driver_error
    end

    def createDirectDriver(securityPlan, address, connection_pool, retryLogic, metricsProvider, config)
      connection_provider = DirectConnectionProvider.new(address, connection_pool)
      driver(:Direct, securityPlan, address, connection_provider, retryLogic, metricsProvider, config)
    end

    def createRoutingDriver(securityPlan, address, connection_pool, eventExecutorGroup, routingSettings, retryLogic, metricsProvider, config)
      connection_provider = createLoadBalancer(address, connection_pool, eventExecutorGroup, config, routingSettings)
      driver(:Routing, securityPlan, address, connection_provider, retryLogic, metricsProvider, config)
    end

    def driver(type, security_plan, address, connection_provider, retry_logic, metrics_provider, config)
      session_factory = SessionFactoryImpl.new(connection_provider, retry_logic, config)
      InternalDriver.new(security_plan, session_factory, metrics_provider, config[:logger]).tap do |driver|
        log = config[:logger]
        log.info { "#{type} driver instance #{driver.object_id} created for server address #{address}" }
      end
    end

    def createLoadBalancer(address, connection_pool, eventExecutorGroup, config, routingSettings)
      load_balancing_strategy = Cluster::Loadbalancing::LeastConnectedLoadBalancingStrategy.new(connection_pool, config[:logger])
      resolver = create_resolver(config)
      Cluster::Loadbalancing::LoadBalancer.new(
        address, routingSettings, connection_pool, eventExecutorGroup,
        config[:logger], load_balancing_strategy, resolver, &method(:domain_name_resolver))
    end

    def create_bootstrap(**args)
      Async::Connection::BootstrapFactory.new_bootstrap(**args)
    end

    protected

    def closeConnectionPoolAndSuppressError(connection_pool, main_error)
      connection_pool.close
    rescue => close_error
      Util::ErrorUtil.add_suppressed(main_error, close_error)
    end

    # def getDomainNameResolver(name)
    #   domain_name_resolver(name).map { |addrinfo| java.net.InetAddress.getByName(addrinfo.canonname) }.to_java(java.net.InetAddress)
    # end

    def domain_name_resolver(name)
      @domain_name_resolver.call(name).flat_map { |n| Addrinfo.getaddrinfo(n, nil, nil, nil, Socket::IPPROTO_TCP) }
    end
  end
end
