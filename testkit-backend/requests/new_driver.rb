module TestkitBackend
  module Requests
    class NewDriver < Request
      def process
        reference('Driver')
      end

      def to_object
        # testkit's NewDriver asserts that exactly one of authToken /
        # authTokenManagerId is set. Either way the factory always
        # gets an AuthTokenManager — bare tokens get wrapped in a
        # static manager here, same as Java's testkit-backend.
        auth_token_manager = if auth_token_manager_id
                               fetch(auth_token_manager_id)
                             else
                               token = authorization_token ?
                                         Request.object_from(authorization_token) :
                                         Neo4j::Driver::AuthTokens.none
                               Neo4j::Driver::Internal::Security::StaticAuthTokenManager.new(token)
                             end
        config = {
          user_agent: user_agent,
          connection_timeout: timeout_duration(connection_timeout_ms),
          fetch_size: fetch_size,
          # TODO: remove driver_metrics from everywhere
          # driver_metrics: true,
          max_transaction_retry_time: timeout_duration(max_tx_retry_time_ms),
          connection_liveness_check_timeout: timeout_duration(liveness_check_timeout_ms),
          max_connection_pool_size: max_connection_pool_size,
          connection_acquisition_timeout: timeout_duration(connection_acquisition_timeout_ms),
          encryption: encrypted,
          telemetry_disabled: telemetry_disabled,
          trust_strategy: trust_strategy(trusted_certificates),
          notification_config: {
            minimum_severity: notifications_min_severity, disabled_categories: notifications_disabled_categories }
        }.compact
        config = config.merge({ resolver: method(:callback_resolver) }) if resolver_registered
        # Build via testkit's own DriverFactory subclass so the
        # `getDomainNameResolver` / `createClock` hooks point at our
        # Ruby resolver proc / TestkitClock — no Java refs on this
        # side, the production-side base class handles the conversion.
        resolver = method(:domain_name_resolver) if domain_name_resolver_registered
        Internal::DriverFactoryWithDomainNameResolver.new(resolver).new_instance(uri, auth_token_manager, config)
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
          { strategy: :trust_system_certificates }
        elsif trusted_certificates.empty?
          { strategy: :trust_all_certificates }
        else
          certs = trusted_certificates.map { |cert| "/usr/local/share/custom-ca-certificates/#{cert}" }
          { strategy: :trust_custom_certificates, cert_files: certs }
        end
      end
    end
  end
end
