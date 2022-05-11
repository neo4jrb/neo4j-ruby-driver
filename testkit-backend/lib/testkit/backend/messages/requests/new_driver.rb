module Testkit::Backend::Messages
  module Requests
    class NewDriver < Request
      def process
        reference('Driver')
      end

      def to_object
        auth_token = Request.object_from(authorizationToken)
        config = { user_agent: userAgent,
                   connection_timeout: timeout_duration(connectionTimeoutMs),
                   fetch_size: fetchSize,
                   driver_metrics: true,
                   encryption: encrypted,
                   trust_strategy: trustedCertificates,
                   connection_acquisition_timeout: timeout_duration(connectionAcquisitionTimeoutMs),
                   liveness_check_timeout_ms: timeout_duration(livenessCheckTimeoutMs),
                   max_transaction_retry_time: timeout_duration(maxTxRetryTimeMs),
                   max_connection_pool_size: maxConnectionPoolSize }
        config = config.merge({ resolver: method(:callback_resolver) }) if resolverRegistered
        if domainNameResolverRegistered
          Neo4j::Driver::GraphDatabase.internal_driver(
            uri, auth_token, config, Neo4j::Driver::Internal::DriverFactory.new(method(:domain_name_resolver)))
        else
          Neo4j::Driver::GraphDatabase.driver(uri, auth_token, **config)
        end
      end

      private

      def domain_name_resolver(name)
        @command_processor.process_response(named_entity('DomainNameResolutionRequired', id: object_id, name: name))
        @command_processor.process(blocking: true).addresses
      end

      def callback_resolver(address)
        @command_processor.process_response(named_entity('ResolverResolutionRequired', id: object_id, address: address))
        @command_processor.process(blocking: true).addresses.map do |addr|
          addr.rpartition(':').then { |host, _, port| Neo4j::Driver::Net::ServerAddress.of(host, port.to_i) }
        end
      end
    end
  end
end
