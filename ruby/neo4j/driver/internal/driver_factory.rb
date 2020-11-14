module Neo4j::Driver::Internal
  class DriverFactory
    class << self
      include Scheme

      def new_instance(uri, authToken, routingSettings, retrySettings, config, securityPlan, eventLoopGroup = nil)
        bootstrap = org.neo4j.driver.internal.async.connection.BootstrapFactory.newBootstrap(eventLoopGroup || config.eventLoopThreads)
        java_uri = java.net.URI.create(uri.to_s)

        address = org.neo4j.driver.internal.BoltServerAddress.new(java_uri)
        newRoutingSettings = routingSettings.withRoutingContext(org.neo4j.driver.internal.cluster.RoutingContext.new(java_uri))

        org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.InternalLoggerFactory.setDefaultFactory(org.neo4j.driver.internal.logging.NettyLogging.new(config.logging))
        eventExecutorGroup = bootstrap.config.group
        retryLogic = org.neo4j.driver.internal.retry.ExponentialBackoffRetryLogic.new(retrySettings, eventExecutorGroup, createClock, config.logging)

        metricsProvider = createDriverMetrics(config, createClock)
        connectionPool = createConnectionPool(authToken, securityPlan, bootstrap, metricsProvider, config,
                                              eventLoopGroup.nil?, newRoutingSettings.routingContext)

        createDriver(uri, securityPlan, address, connectionPool, eventExecutorGroup, newRoutingSettings, retryLogic, metricsProvider, config)
      end

      private

      def createConnectionPool(authToken, securityPlan, bootstrap, metricsProvider, config, ownsEventLoopGroup, routingContext)
        clock = createClock
        settings = org.neo4j.driver.internal.ConnectionSettings.new(authToken, config.userAgent, config.connectionTimeoutMillis)
        connector = createConnector(settings, securityPlan, config, clock, routingContext)
        poolSettings = org.neo4j.driver.internal.async.pool.PoolSettings.new(config.maxConnectionPoolSize,
                                                                             config.connectionAcquisitionTimeoutMillis, config.maxConnectionLifetimeMillis,
                                                                             config.idleTimeBeforeConnectionTest
        )
        org.neo4j.driver.internal.async.pool.ConnectionPoolImpl.new(connector, bootstrap, poolSettings, metricsProvider.metricsListener, config.logging, clock, ownsEventLoopGroup)
      end

      def createDriverMetrics(config, clock)
        config.isMetricsEnabled ? org.neo4j.driver.internal.metrics.InternalMetricsProvider.new(clock, config.logging) : org.neo4j.driver.internal.metrics.MetricsProvider::METRICS_DISABLED_PROVIDER
      end

      def createResolver(config)
        config.resolver || ->(address) { java.util.HashSet.new([address]) }
      end

      def assertNoRoutingContext(uri, routingSettings)
        routingContext = routingSettings.routingContext
        if routingContext.isDefined
          raise ArgumentError, "Routing parameters are not supported with scheme 'bolt'. Given URI: '#{uri}'"
        end
      end

      def createConnector(settings, securityPlan, config, clock, routingContext)
        org.neo4j.driver.internal.async.connection.ChannelConnectorImpl.new(settings, securityPlan, config.logging, clock, routingContext)
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
        sessionFactory = constructor_send(org.neo4j.driver.internal.SessionFactoryImpl, connectionProvider, retryLogic, config)
        InternalDriver.new(securityPlan, sessionFactory, metricsProvider, config.logging).tap do |driver|
          log = config.logging.get_log(org.neo4j.driver.Driver.name)
          log.info("#{type} driver instance %s created for server address %s", driver.object_id, address)
        end
      end

      def createLoadBalancer(address, connectionPool, eventExecutorGroup, config, routingSettings)
        loadBalancingStrategy = org.neo4j.driver.internal.cluster.loadbalancing.LeastConnectedLoadBalancingStrategy.new(connectionPool, config.logging)
        resolver = createResolver(config)
        org.neo4j.driver.internal.cluster.loadbalancing.LoadBalancer.new(
          address, routingSettings, connectionPool, eventExecutorGroup, createClock,
          config.logging, loadBalancingStrategy, resolver)
      end

      def createClock
        org.neo4j.driver.internal.util.Clock.SYSTEM
      end

      def closeConnectionPoolAndSuppressError(connectionPool, mainError)
        org.neo4j.driver.internal.util.Futures.blockingGet(connectionPool.close)
      rescue Exception => closeError
        org.neo4j.driver.internal.util.ErrorUtil.addSuppressed(mainError, closeError)
      end
    end
  end
end
