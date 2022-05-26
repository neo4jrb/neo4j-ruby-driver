module Testkit::Backend::Messages
  module Requests
    class NewDriver < Request
      def process
        reference('Driver')
      end

      def to_object
        auth_token = Request.object_from(authorization_token)
        config = {
          user_agent: user_agent,
          connection_timeout: timeout_duration(connection_timeout_ms),
          fetch_size: fetch_size,
          driver_metrics: true,
          max_transaction_retry_time: timeout_duration(max_tx_retry_time_ms),
          connection_liveness_check_timeout: timeout_duration(liveness_check_timeout_ms),
          max_connection_pool_size: max_connection_pool_size,
          connection_acquisition_timeout: timeout_duration(connection_acquisition_timeout_ms),
          encryption: encrypted,
          trust_strategy: trust_strategy(trusted_certificates)
        }
        config = config.merge({ resolver: method(:callback_resolver) }) if resolver_registered
        if domain_name_resolver_registered
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

      def trust_strategy(trusted_certificates)
        if trusted_certificates.nil?
          {strategy: :trust_system_certificates}
        elsif trusted_certificates.empty?
          {strategy: :trust_all_certificates}
        else
          certs = trusted_certificates.map{ |cert| "/usr/local/share/custom-ca-certificates/#{cert}" }
          {strategy: :trust_custom_certificates, cert_files: certs}
        end
      end
    end
  end
end
