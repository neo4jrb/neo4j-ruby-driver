# frozen_string_literal: true

module Neo4j::Driver
  class GraphDatabase
    class << self
      extend AutoClosable
      extend Synchronizable
      auto_closable :driver, :routing_driver
      sync :driver

      def driver(uri, auth_token = nil, **config)
        internal_driver(uri, auth_token, config, Internal::DriverFactory.new)
      end

      def internal_driver(uri, auth_token, config, factory)
        uri = URI(uri)
        config = Config.new(**config)

        factory.new_instance(
          uri,
          auth_token || AuthTokens.none,
          config.routing_settings,
          config[:max_transaction_retry_time],
          config,
          config[:security_settings].create_security_plan(uri.scheme)
        )
      end

      def routing_driver(routing_uris, auth_toke, **config)
        assert_routing_uris(routing_uris)
        log = Config.new(**config)[:logger]

        routing_uris.each do |uri|
          driver = driver(uri, auth_toke, **config)
          begin
            return driver.tap(&:verify_connectivity)
          rescue Exceptions::ServiceUnavailableException => e
            log.warn { "Unable to create routing driver for URI: #{uri}\n#{e}" }
            close_driver(driver, uri, log)
          rescue Exception => e
            close_driver(driver, uri, log)
            raise e
          end
        end

        raise Exceptions::ServiceUnavailableException, 'Failed to discover an available server'
      end

      private

      def bolt_version(version)
        pad(version.split(/[.\-]/).map(&:to_i), 4).reverse
      end

      def ruby_version(bolt_version)
        bolt_version.unpack('C*').reverse.map(&:to_s).join('.')
      end

      def bolt_versions(*versions)
        pad(versions[0..3].map(&method(:bolt_version)).flatten, 16).pack('C*')
      end

      def pad(arr, n)
        arr + [0] * [0, n - arr.size].max
      end

      def close_driver(driver, uri, log)
        driver.close
      rescue StandardError => close_error
        log.warn { "Unable to close driver towards URI: #{uri}\n#{close_error}" }
      end

      def assert_routing_uris(uris)
        uris.find { |uri| URI(uri).scheme != Neo4j::Driver::Internal::Scheme::NEO4J_URI_SCHEME }&.tap do |uri|
          raise ArgumentError, "Illegal URI scheme, expected '#{Internal::Scheme::NEO4J_URI_SCHEME}' in '#{uri}'"
        end
      end
    end
  end
end
