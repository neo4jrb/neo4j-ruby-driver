# frozen_string_literal: true

module Neo4j
  module Driver
    class Config < Hash
      class TrustStrategy
        TRUST_ALL_CERTIFICATES = :trust_all_certificates
        TRUST_CUSTOM_CA_SIGNED_CERTIFICATES = :trust_custom_ca_signed_certificates
        TRUST_SYSTEM_CA_SIGNED_CERTIFICATES = :trust_system_ca_signed_certificates

        attr_reader :strategy, :cert_files, :revocation_strategy

        # Sample config:
        # {
        #   trust_strategy: {
        #     strategy: :trust_custom_ca_signed_certificates,
        #     cert_files: ['some_path', 'another_path'],
        #     revocation_strategy: :no_checks, # or :verify_if_present, :strict
        #     hostname_verification: true
        #   },
        #   encryption: true
        # }
        def initialize(**config)
          @strategy = config[:strategy]
          @cert_files = config[:cert_files]
          @revocation_strategy = config[:revocation_strategy] || Neo4j::Driver::Internal::RevocationStrategy::NO_CHECKS
          @hostname_verification_enabled = config[:hostname_verification] || false
        end

        def self.trust_all_certificates
          new(trust_strategy: TRUST_ALL_CERTIFICATES)
        end

        def hostname_verification_enabled?
          @hostname_verification_enabled
        end
      end

      # Console.logger = ::Logger.new(STDOUT, level: :debug)
      DEFAULTS = {
        logger: ::Logger.new(nil),
        # logger: ::Logger.new(STDOUT, level: :debug),
        # logger: Console.logger,
        leaked_sessions_logging: false,
        max_connection_pool_size: Internal::Async::Pool::PoolSettings::DEFAULT_MAX_CONNECTION_POOL_SIZE,
        idle_time_before_connection_test: Internal::Async::Pool::PoolSettings::DEFAULT_IDLE_TIME_BEFORE_CONNECTION_TEST,
        max_connection_lifetime: Internal::Async::Pool::PoolSettings::DEFAULT_MAX_CONNECTION_LIFETIME,
        connection_acquisition_timeout: Internal::Async::Pool::PoolSettings::DEFAULT_CONNECTION_ACQUISITION_TIMEOUT,
        routing_failure_limit: Internal::Cluster::RoutingSettings::DEFAULT.max_routing_failures,
        routing_retry_delay: Internal::Cluster::RoutingSettings::DEFAULT.retry_timeout_delay,
        routing_table_purge_delay: Internal::Cluster::RoutingSettings::DEFAULT.routing_table_purge_delay,
        user_agent: "neo4j-ruby/#{Neo4j::Driver::VERSION}",
        connection_timeout: 30.seconds,
        driver_metrics: false,
        fetch_size: Internal::Handlers::Pulln::FetchSizeUtil::DEFAULT_FETCH_SIZE,
        event_loop_threads: 0,

        # TODO: Still to cleanup
        encryption: false, # :set_transport
        keep_alive: true, # BoltSocketOptions_set_keep_alive
        # connection_liveness_check_timeout: -1, # Not configured
        max_transaction_retry_time: Internal::Retry::ExponentialBackoffRetryLogic::DEFAULT_MAX_RETRY_TIME,
        metrics_enabled: false,
        # resolver: nil # :set_address_resolver
        trust_strategy: { strategy: :trust_all_certificates }
      }.freeze

      def initialize(**config)
        merge!(DEFAULTS).merge!(config.compact)
        init_security_and_trust_config
      end

      def routing_settings
        Internal::Cluster::RoutingSettings.new(
          *values_at(:routing_failure_limit, :routing_retry_delay, :routing_table_purge_delay))
      end

      private

      def init_security_and_trust_config
        relevant = %i[encryption trust_strategy]
        customized = slice(*relevant) == DEFAULTS.slice(*relevant)
        merge!(security_settings: Neo4j::Driver::Internal::SecuritySetting.new(
          fetch(:encryption), TrustStrategy.new(**fetch(:trust_strategy)), customized),
        )
      end
    end
  end
end
