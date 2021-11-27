module Neo4j::Driver::Internal
  class DriverFactory
    include Scheme
    include Neo4j::Driver::Ext::NeoConverter

    def initialize(domain_name_resolver = ->(name) { [name] })
      @domain_name_resolver = domain_name_resolver
    end

    def new_instance(uri, auth_token, routingSettings, retrySettings, config, securityPlan, eventLoopGroup = nil)
      bootstrap = org.neo4j.driver.internal.async.connection.BootstrapFactory.newBootstrap(eventLoopGroup || config.java_config.eventLoopThreads)
      java_uri = java.net.URI.create(uri.to_s)

      address = org.neo4j.driver.internal.BoltServerAddress.new(java_uri)
      newRoutingSettings = routingSettings.withRoutingContext(org.neo4j.driver.internal.cluster.RoutingContext.new(java_uri))

      org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.InternalLoggerFactory.setDefaultFactory(org.neo4j.driver.internal.logging.NettyLogging.new(config.java_config.logging))
      eventExecutorGroup = bootstrap.config.group
      retry_logic = Retry::ExponentialBackoffRetryLogic.new(retrySettings, config[:logger])

      metricsProvider = createDriverMetrics(config, createClock)
      connectionPool = create_connection_pool(auth_token, securityPlan, bootstrap, metricsProvider, config,
                                              eventLoopGroup.nil?, newRoutingSettings.routingContext)

      createDriver(uri, securityPlan, address, connectionPool, eventExecutorGroup, newRoutingSettings, retry_logic, metricsProvider, config)
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
        config[:idle_time_before_connection_test].in_milliseconds
      )
      org.neo4j.driver.internal.async.pool.ConnectionPoolImpl.new(connector, bootstrap, poolSettings, metricsProvider.metricsListener, config.java_config.logging, clock, ownsEventLoopGroup)
    end

    def createDriverMetrics(config, clock)
      if config[:metrics_enabled]
        org.neo4j.driver.internal.metrics.InternalMetricsProvider.new(config.java_config, config.logging)
      else
        org.neo4j.driver.internal.metrics.MetricsProvider::METRICS_DISABLED_PROVIDER
      end
    end

    def createResolver(config)
      config[:resolver] || ->(address) { [address] }
    end

    def assertNoRoutingContext(uri, routingSettings)
      routingContext = routingSettings.routingContext
      if routingContext.isDefined
        raise ArgumentError, "Routing parameters are not supported with scheme 'bolt'. Given URI: '#{uri}'"
      end
    end

    def createConnector(settings, securityPlan, config, clock, routingContext)
      org.neo4j.driver.internal.async.connection.ChannelConnectorImpl.new(
        settings, securityPlan, config.java_config.logging, clock, routingContext, &method(:getDomainNameResolver))
    end

    def createDriver(uri, securityPlan, address, connectionPool, eventExecutorGroup, routingSettings, retryLogic, metricsProvider, config)
      if routing_scheme?(uri.scheme.downcase)
        createRoutingDriver(securityPlan, address, connectionPool, eventExecutorGroup, routingSettings, retryLogic, metricsProvider, config)
      else
        assertNoRoutingContext(uri, routingSettings)
        createDirectDriver(securityPlan, address, connectionPool, retryLogic, metricsProvider, config)
      end
    rescue Exception => driverError
      # we need to close the connection pool if driver creation threw exception
      closeConnectionPoolAndSuppressError(connectionPool, driverError)
      raise driverError
    end

    def createDirectDriver(securityPlan, address, connectionPool, retryLogic, metricsProvider, config)
      connectionProvider = constructor_send(org.neo4j.driver.internal.DirectConnectionProvider, address, connectionPool)
      driver(:Direct, securityPlan, address, connectionProvider, retryLogic, metricsProvider, config)
    end

    def createRoutingDriver(securityPlan, address, connectionPool, eventExecutorGroup, routingSettings, retryLogic, metricsProvider, config)
      connectionProvider = createLoadBalancer(address, connectionPool, eventExecutorGroup, config, routingSettings)
      driver(:Routing, securityPlan, address, connectionProvider, retryLogic, metricsProvider, config)
    end

    def constructor_send(klass, *args)
      klass.java_class.declared_constructors.first.tap { |c| c.accessible = true }.new_instance(*args).to_java
    end

    def driver(type, securityPlan, address, connectionProvider, retryLogic, metricsProvider, config)
      session_factory = SessionFactoryImpl.new(connectionProvider, retryLogic, config)
      InternalDriver.new(securityPlan, session_factory, metricsProvider, config[:logger]).tap do |driver|
        log = config[:logger]
        log.info { "#{type} driver instance #{driver.object_id} created for server address #{address}" }
      end
    end

    def createLoadBalancer(address, connectionPool, eventExecutorGroup, config, routingSettings)
      loadBalancingStrategy = org.neo4j.driver.internal.cluster.loadbalancing.LeastConnectedLoadBalancingStrategy.new(connectionPool, config.java_config.logging)
      resolver = ->(address) { java.util.HashSet.new(createResolver(config).call(address)) }
      org.neo4j.driver.internal.cluster.loadbalancing.LoadBalancer.new(
        address, routingSettings, connectionPool, eventExecutorGroup, createClock,
        config.java_config.logging, loadBalancingStrategy, resolver, &method(:getDomainNameResolver))
    end

    def createClock
      Java::OrgNeo4jDriverInternalUtil::Clock::SYSTEM
    end

    def closeConnectionPoolAndSuppressError(connectionPool, mainError)
      org.neo4j.driver.internal.util.Futures.blockingGet(connectionPool.close)
    rescue Exception => closeError
      org.neo4j.driver.internal.util.ErrorUtil.addSuppressed(mainError, closeError)
    end

    protected

    def getDomainNameResolver(name)
      domain_name_resolver(name).map { |addrinfo| java.net.InetAddress.getByName(addrinfo.canonname) }.to_java(java.net.InetAddress)
    end

    def domain_name_resolver(name)
      @domain_name_resolver.call(name).flat_map { |n| Addrinfo.getaddrinfo(n, nil, nil, nil, Socket::IPPROTO_TCP) }
    end
  end
end
