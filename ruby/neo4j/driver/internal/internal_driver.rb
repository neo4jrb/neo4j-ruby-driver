module Neo4j::Driver
  module Internal
    class InternalDriver
      extend AutoClosable
      attr_reader :session_factory, :metrics_provider
      # delegate :verify_connectivity, to: :session_factory
      delegate :metrics, :metrics_enabled?, to: :metrics_provider
      auto_closable :session

      def initialize(security_plan, session_factory, metrics_provider, logger)
        @closed = Concurrent::AtomicBoolean.new(false)
        @security_plan = security_plan
        @session_factory = session_factory
        @metrics_provider = metrics_provider
        @log = logger
      end

      def session(**session_config)
        InternalSession.new(new_session(**session_config))
      end

      def rx_session(**session_config)
        InternalRxSession.new(new_session(**session_config))
      end

      def async_session(**session_config)
        InternalAsyncSession.new(new_session(**session_config))
      end

      def encrypted?
        assert_open!
        @security_plan.requires_encryption?
      end

      def close
        Sync { close_async }
      end

      def close_async
        return nil unless @closed.make_true
        @log.info { "Closing driver instance #{object_id}" }
        session_factory.close
      end

      def verify_connectivity_async
        session_factory.verify_connectivity
      end

      def supports_multi_db?
        Sync { supports_multi_db_async? }
      end

      def supports_multi_db_async?
        session_factory.supports_multi_db?
      end

      def verify_connectivity
        Sync { verify_connectivity_async }
      end

      def new_session(**config)
        assert_open!
        session_factory.new_instance(**config.compact)
      ensure
        # session does not immediately acquire connection, it is fine to just throw
        assert_open!
      end

      private

      def assert_open!
        raise Exceptions::IllegalStateException, 'This driver instance has already been closed' if @closed.true?
      end
    end
  end
end
