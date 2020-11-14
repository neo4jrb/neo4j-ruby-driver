module Neo4j::Driver
  module Internal
    class InternalDriver
      extend AutoClosable
      include Ext::ConfigConverter
      include Ext::ExceptionCheckable

      attr_reader :session_factory
      # delegate :verify_connectivity, to: :session_factory
      auto_closable :session

      def initialize(security_plan, session_factory, metrics_provider, logging)
        @closed = Concurrent::AtomicBoolean.new(false)
        @security_plan = security_plan
        @session_factory = session_factory
        @metrics_provider = metrics_provider
        @log = logging.get_log(self.class.name)
      end

      def session(**session_config)
        org.neo4j.driver.internal.InternalSession.new(new_session(to_java_config(org.neo4j.driver.SessionConfig, session_config)))
      end

      def close
        if @closed.make_true
          org.neo4j.driver.internal.util.Futures.blockingGet(session_factory.close)
          @log.info('Closing driver instance %s', object_id)
        end
      end

      def verify_connectivity
        check { org.neo4j.driver.internal.util.Futures.blockingGet(session_factory.verify_connectivity) }
      end

      def new_session(config)
        assert_open
        session_factory.new_instance(config)
      ensure
        # session does not immediately acquire connection, it is fine to just throw
        assert_open
      end

      private

      def assert_open
        raise Exceptions::IllegalStateException, 'This driver instance has already been closed' if @closed.true?
      end
    end
  end
end
