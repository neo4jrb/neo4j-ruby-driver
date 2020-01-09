# frozen_string_literal: true

module Neo4j
  module Driver
    class Config < Hash
      class TrustStrategy
        class << self
          def trust_all_certificates; end
        end
      end

      class << self
        def default_config
          new.merge(
             logger: ActiveSupport::Logger.new(STDOUT, level: ::Logger::INFO), # :set_log
             leaked_session_logging: false,
             #connection_liveness_check_timeot: -1, # Not configured
             max_connection_lifetime: 1.hour, # :set_max_connection_life_time
             max_connection_pool_size: 100, #:set_max_pool_size
             connection_acquisition_timeout: 1.minute, #:set_max_connection_acquisition_time
             encryption: true, # :set_transport
             trust_strategy: :trust_all_certificates,
             connection_timeout: 30.seconds, # BoltSocketOptions_set_connect_timeout
             max_transaction_retry_time: Internal::Retry::ExponentialBackoffRetryLogic::DEFAULT_MAX_RETRY_TIME,
             #resolver: nil # :set_address_resolver
             # ?????? BoltSocketOptions_set_keep_alive
             # ???? BoltConfig_set_user_agent
          )
        end
      end
    end
  end
end
