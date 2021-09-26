module Neo4j::Driver::Internal
  class DriverFactory
    class << self
      include Scheme

      def new_instance(uri, authToken, routingSettings, retrySettings, config, securityPlan, eventLoopGroup = nil)
        bootstrap = org.neo4j.driver.internal.async.connection.BootstrapFactory.newBootstrap(eventLoopGroup || config.java_config.eventLoopThreads)
        java_uri = java.net.URI.create(uri.to_s)

        address = org.neo4j.driver.internal.BoltServerAddress.new(java_uri)
        newRoutingSettings = routingSettings.withRoutingContext(org.neo4j.driver.internal.cluster.RoutingContext.new(java_uri))

        org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.InternalLoggerFactory.setDefaultFactory(org.neo4j.driver.internal.logging.NettyLogging.new(config.java_config.logging))
        eventExecutorGroup = bootstrap.config.group
        retryLogic = Retry::ExponentialBackoffRetryLogic.new(retrySettings, config[:logger])

        metricsProvider = createDriverMetrics(config, createClock)
        connectionPool = createConnectionPool(authToken, securityPlan, bootstrap, metricsProvider, config,
                                              eventLoopGroup.nil?, newRoutingSettings.routingContext)

        createDriver(uri, securityPlan, address, connectionPool, eventExecutorGroup, newRoutingSettings, retryLogic, metricsProvider, config)
      end

      private

      def createConnectionPool(authToken, securityPlan, bootstrap, metricsProvider, config, ownsEventLoopGroup, routingContext)
        clock = createClock
        settings = org.neo4j.driver.internal.ConnectionSettings.new(authToken, config.java_config.userAgent, config.java_config.connectionTimeoutMillis)
        connector = createConnector(settings, securityPlan, config, clock, routingContext)
        poolSettings = org.neo4j.driver.internal.async.pool.PoolSettings.new(config.java_config.maxConnectionPoolSize,
                                                                             config.java_config.connectionAcquisitionTimeoutMillis, config.java_config.maxConnectionLifetimeMillis,
                                                                             config.java_config.idleTimeBeforeConnectionTest
        )
        org.neo4j.driver.internal.async.pool.ConnectionPoolImpl.new(connector, bootstrap, poolSettings, metricsProvider.metricsListener, config.java_config.logging, clock, ownsEventLoopGroup)
      end

      def createDriverMetrics(config, clock)
        config.java_config.isMetricsEnabled ? org.neo4j.driver.internal.metrics.InternalMetricsProvider.new(config.java_config, config.logging) : org.neo4j.driver.internal.metrics.MetricsProvider::METRICS_DISABLED_PROVIDER
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
          settings, securityPlan, config.java_config.logging, clock, routingContext, getDomainNameResolver)
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
          config.java_config.logging, loadBalancingStrategy, resolver, getDomainNameResolver)
      end

      def createClock
        Java::OrgNeo4jDriverInternalUtil::Clock.SYSTEM
      end

      def closeConnectionPoolAndSuppressError(connectionPool, mainError)
        org.neo4j.driver.internal.util.Futures.blockingGet(connectionPool.close)
      rescue Exception => closeError
        org.neo4j.driver.internal.util.ErrorUtil.addSuppressed(mainError, closeError)
      end

      protected

      def getDomainNameResolver()
        org.neo4j.driver.internal.DefaultDomainNameResolver.getInstance()
      end
    end
  end
end
