# frozen_string_literal: true

module Neo4j
  module Driver
    class Config < Hash
      include Ext::ConfigConverter

      DEFAULTS = {
        connection_acquisition_timeout: 1.minute, #:set_max_connection_acquisition_time
        connection_timeout: 30.seconds, # BoltSocketOptions_set_connect_timeout
        encryption: false, # :set_transport
        fetch_size: 1000,
        idle_time_before_connection_test: -1,
        keep_alive: true, # BoltSocketOptions_set_keep_alive
        logger: ActiveSupport::Logger.new(STDOUT, level: ::Logger::ERROR), # :set_log
        leaked_session_logging: false,
        #connection_liveness_check_timeout: -1, # Not configured
        max_connection_lifetime: 1.hour, # :set_max_connection_life_time
        max_connection_pool_size: 100, #:set_max_pool_size
        max_transaction_retry_time: Internal::Retry::ExponentialBackoffRetryLogic::DEFAULT_MAX_RETRY_TIME,
        metrics_enabled: false,
        # resolver: nil # :set_address_resolver
        trust_strategy: Neo4j::Driver::Config::TrustStrategy.trust_all_certificates,
        user_agent: "neo4j-java/#{Neo4j::Driver::VERSION}".freeze
      }

      class TrustStrategy
        TRUST_ALL_CERTIFICATES = :trust_all_certificates
        TRUST_CUSTOM_CA_SIGNED_CERTIFICATES = :trust_custom_ca_signed_certificates
        TRUST_SYSTEM_CA_SIGNED_CERTIFICATES = :trust_system_ca_signed_certificates

        attr_reader :strategy, :cert_file, :revocation_strategy

        def initialize(**config)
          @strategy = config[:trust_strategy]
          @cert_file = config[:cert_file]
          @revocation_strategy = config[:revocation_strategy] || Neo4j::Driver::Internal::RevocationStrategy::NO_CHECKS
          @hostname_verification_enabled = config[:hostname_verification_enabled] || false
        end

        def self.trust_all_certificates
          new(trust_strategy: TRUST_ALL_CERTIFICATES)
        end

        def default_trust_strategy?
          strategy == TRUST_ALL_CERTIFICATES
        end

        def hostname_verification_enabled?
          hostname_verification_enabled
        end

        def cert_file_to_java
          java.io.File.new(cert_file.path)
        end
      end

      def initialize(**config)
        init_security_and_trust_config(config)
        merge!(DEFAULTS).merge!(config.compact).merge!(
          java_config: to_java_config(org.neo4j.driver.Config, config.tap { |hash| hash.delete(:trust_strategy) })
        )
      end

      def java_config
        fetch(:java_config)
      end

      private

      def init_security_and_trust_config(config)
        trust_strategy = config[:trust_strategy] ? TrustStrategy.new(config) || DEFAULTS[:trust_strategy]
        merge!(
          security_settings: Neo4j::Driver::Internal::SecuritySetting.new(config[:encryption], trust_strategy),
          trust_strategy: trust_strategy
        )
      end
    end
  end
end
