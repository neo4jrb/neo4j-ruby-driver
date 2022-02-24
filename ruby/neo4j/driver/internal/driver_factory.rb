module Neo4j::Driver::Internal
  class DriverFactory
    include Scheme
    NO_ROUTING_CONTEXT_ERROR_MESSAGE = "Routing parameters are not supported with scheme 'bolt'. Given URI: "

    def initialize(domain_name_resolver = ->(name) { [name] })
      @domain_name_resolver = domain_name_resolver
    end

    def new_instance(uri, auth_token, routing_settings, retry_settings, config, securityPlan, event_loop_group = nil)
      bootstrap = create_bootstrap(
        **event_loop_group ? { event_loop_group: event_loop_group } : { thread_count: config[:event_loop_threads] }
      )

      address = BoltServerAddress.new(uri: uri)
      new_routing_settings = routing_settings.with_routing_context(Cluster::RoutingContext.new(uri))

      # org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.InternalLoggerFactory.setDefaultFactory(org.neo4j.driver.internal.logging.NettyLogging.new(config.logging))
      event_executor_group = bootstrap.group
      retry_logic = Retry::ExponentialBackoffRetryLogic.new(retry_settings, event_executor_group, config[:logger])

      metricsProvider = createDriverMetrics(config)
      connectionPool = create_connection_pool(auth_token, securityPlan, bootstrap, metricsProvider, config,
                                              event_loop_group.nil?, new_routing_settings.routing_context)

      create_driver(uri, securityPlan, address, connectionPool, event_executor_group, new_routing_settings, retry_logic, metricsProvider, config)
    end

    private

    def create_connection_pool(auth_token, securityPlan, bootstrap, metricsProvider, config, ownsEventLoopGroup, routingContext)
      clock = createClock
      settings = org.neo4j.driver.internal.ConnectionSettings.new(
        org.neo4j.driver.internal.security.InternalAuthToken.new(to_neo(auth_token).transform_values(&org.neo4j.driver.Values.method(:value))), config[:user_agent], config[:connection_timeout].in_milliseconds
      )
      connector = createConnector(settings, securityPlan, config, clock, routingContext)
      poolSettings = org.neo4j.driver.internal.async.pool.PoolSettings.new(
        config[:max_connection_pool_size],
        config[:connection_acquisition_timeout].in_milliseconds,
        config[:max_connection_lifetime].in_milliseconds,
        config[:idle_time_before_connection_test]&.in_milliseconds || -1 # TODO: remember to get rid of -1
      )
      org.neo4j.driver.internal.async.pool.ConnectionPoolImpl.new(connector, bootstrap, poolSettings, metricsProvider.metricsListener, config.logging, clock, ownsEventLoopGroup)
    end

    def createDriverMetrics(config)
      if config[:metrics_enabled]
        Metrics::InternalMetricsProvider.new(config.java_config, config.logging)
      else
        Metrics::MetricsProvider::METRICS_DISABLED_PROVIDER
      end
    end

    def create_resolver(config)
      config[:resolver] || ->(address) { [address] }
    end

    def assertNoRoutingContext(uri, routing_settings)
      routing_context = routing_settings.routing_context
      if routing_context.defined?
        raise ArgumentError, "Routing parameters are not supported with scheme 'bolt'. Given URI: '#{uri}'"
      end
    end

    def createConnector(settings, securityPlan, config, clock, routingContext)
      Async::Connection::ChannelConnectorImpl.new(
        settings, securityPlan, config[:logger], clock, routingContext, &method(:getDomainNameResolver))
    end

    def create_driver(uri, securityPlan, address, connectionPool, eventExecutorGroup, routing_settings, retryLogic, metricsProvider, config)
      if routing_scheme?(uri.scheme.downcase)
        createRoutingDriver(securityPlan, address, connectionPool, eventExecutorGroup, routing_settings, retryLogic, metricsProvider, config)
      else
        assertNoRoutingContext(uri, routing_settings)
        createDirectDriver(securityPlan, address, connectionPool, retryLogic, metricsProvider, config)
      end
    rescue Exception => driverError
      # we need to close the connection pool if driver creation threw exception
      closeConnectionPoolAndSuppressError(connectionPool, driverError)
      raise driverError
    end

    def createDirectDriver(securityPlan, address, connectionPool, retryLogic, metricsProvider, config)
      connection_provider = DirectConnectionProvider.new(address, connectionPool)
      driver(:Direct, securityPlan, address, connection_provider, retryLogic, metricsProvider, config)
    end

    def createRoutingDriver(securityPlan, address, connectionPool, eventExecutorGroup, routingSettings, retryLogic, metricsProvider, config)
      connection_provider = createLoadBalancer(address, connectionPool, eventExecutorGroup, config, routingSettings)
      driver(:Routing, securityPlan, address, connection_provider, retryLogic, metricsProvider, config)
    end

    def driver(type, securityPlan, address, connectionProvider, retryLogic, metricsProvider, config)
      session_factory = SessionFactoryImpl.new(connectionProvider, retryLogic, config)
      InternalDriver.new(securityPlan, session_factory, metricsProvider, config[:logger]).tap do |driver|
        log = config[:logger]
        log.info { "#{type} driver instance #{driver.object_id} created for server address #{address}" }
      end
    end

    def createLoadBalancer(address, connectionPool, eventExecutorGroup, config, routingSettings)
      load_balancing_strategy = Cluster::Loadbalancing::LeastConnectedLoadBalancingStrategy.new(connectionPool, config[:logger])
      resolver = create_resolver(config)
      Cluster::Loadbalancing::LoadBalancer.new(
        address, routingSettings, connectionPool, eventExecutorGroup,
        config[:logger], load_balancing_strategy, resolver, &method(:getDomainNameResolver))
    end

    def create_bootstrap(**args)
      Async::Connection::BootstrapFactory.new_bootstrap(**args)
    end

    protected

    def closeConnectionPoolAndSuppressError(connectionPool, mainError)
      org.neo4j.driver.internal.util.Futures.blockingGet(connectionPool.close)
    rescue Exception => closeError
      org.neo4j.driver.internal.util.ErrorUtil.addSuppressed(mainError, closeError)
    end

    def getDomainNameResolver(name)
      domain_name_resolver(name).map { |addrinfo| java.net.InetAddress.getByName(addrinfo.canonname) }.to_java(java.net.InetAddress)
    end

    def domain_name_resolver(name)
      @domain_name_resolver.call(name).flat_map { |n| Addrinfo.getaddrinfo(n, nil, nil, nil, Socket::IPPROTO_TCP) }
    end
  end
end
