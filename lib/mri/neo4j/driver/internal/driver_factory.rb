# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # MRI flavour of the impl-agnostic `Internal::DriverFactory`
      # seam. Owns the actual driver-construction logic — URI
      # validation + `Internal::Driver.new(...)` — so that
      # `GraphDatabase.driver` is just the convenience entry point
      # that wraps the user-supplied `AuthToken` in a
      # `StaticAuthTokenManager` and calls us.
      #
      # The `to_*` converters are identity (MRI doesn't bridge any
      # types); `get_domain_name_resolver` / `create_clock` raise
      # since MRI doesn't have those hooks wired yet — testkit's
      # subclass overrides both so the production raisers never
      # fire in the tests we currently run.
      class DriverFactory
        VALID_SCHEMES = %w[bolt bolt+s bolt+ssc neo4j neo4j+s neo4j+ssc].freeze

        def to_domain_name_resolver(resolver_proc)
          resolver_proc
        end

        def to_clock(clock)
          clock
        end

        def get_domain_name_resolver
          raise NotImplementedError, 'MRI driver does not yet expose a domain-name-resolver hook'
        end

        def create_clock
          raise NotImplementedError, 'MRI driver does not yet expose a custom clock hook'
        end

        # `client_certificate_manager` is accepted for a uniform cross-impl
        # signature but ignored — MRI doesn't implement mutual-TLS client
        # certificates (Feature:API:SSLClientCertificate is JRuby-only), and
        # testkit never supplies one to the MRI flavour.
        def new_instance(uri, auth_token_manager, client_certificate_manager: nil, **config)
          validate_uri(uri)
          # Retain the manager (not a frozen token): the connection
          # provider consults it for the current token on every acquire
          # and on security failures, so token refresh / re-auth works.
          Driver.new(uri, auth_token_manager, config)
        end

        private

        def validate_uri(uri)
          parsed = URI(uri)
          raise ArgumentError, 'Scheme must not be null' if parsed.scheme.nil? || parsed.scheme.empty?
          raise ArgumentError, "Unsupported URI scheme: #{parsed.scheme}" unless VALID_SCHEMES.include?(parsed.scheme)
        rescue URI::InvalidURIError
          raise ArgumentError, 'Scheme must not be null'
        end
      end
    end
  end
end
