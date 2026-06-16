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
      # The factory is also the single owner of the driver's non-public
      # extension hooks: `getDomainNameResolver` (nil by default = system DNS)
      # and `create_clock` (still raises — no MRI clock hook yet). testkit's
      # subclass overrides them. Rather than leaking these into the
      # user-facing config, new_instance bakes them into the ConnectionProvider
      # it assembles, so the Driver never sees them. The `to_*` converters are
      # identity (MRI doesn't bridge any types).
      class DriverFactory
        VALID_SCHEMES = %w[bolt bolt+s bolt+ssc neo4j neo4j+s neo4j+ssc].freeze

        def to_domain_name_resolver(resolver_proc)
          resolver_proc
        end

        def to_clock(clock)
          clock
        end

        # camelCase to match the name Java's DriverFactory exposes and that
        # subclasses (testkit's DriverFactoryWithDomainNameResolver) call
        # `super` on. Default: no custom resolver (system DNS is used). The
        # subclass returns its proc when one is registered, else falls through
        # to this via `super`.
        def getDomainNameResolver = nil

        def create_clock
          raise NotImplementedError, 'MRI driver does not yet expose a custom clock hook'
        end

        # `client_certificate_manager` is accepted for a uniform cross-impl
        # signature but ignored — MRI doesn't implement mutual-TLS client
        # certificates (Feature:API:SSLClientCertificate is JRuby-only), and
        # testkit never supplies one to the MRI flavour.
        def new_instance(uri, auth_token_manager, client_certificate_manager: nil, **config)
          validate_uri(uri)
          # The factory is the single place that knows about the non-public
          # extension hooks (the domain-name resolver today; createClock and
          # others later). It assembles a fully-wired ConnectionProvider with
          # those baked in and hands it to the Driver, so the Driver and the
          # user-facing `config` never carry these hooks.
          #
          # Retain the manager (not a frozen token): the provider consults it
          # for the current token on every acquire and on security failures,
          # so token refresh / re-auth works.
          provider = build_connection_provider(URI(uri), auth_token_manager, config)
          Driver.new(uri, config, provider)
        end

        private

        def build_connection_provider(uri, auth_manager, options)
          klass = uri.scheme.start_with?('neo4j') ? Routing::LoadBalancer : Direct::ConnectionProvider
          klass.new(uri, auth_manager, options, domain_name_resolver: getDomainNameResolver)
        end

        def validate_uri(uri)
          parsed = URI(uri)
          raise ArgumentError, 'Scheme must not be null' if parsed.scheme.nil? || parsed.scheme.empty?
          raise ArgumentError, "Unsupported URI scheme: #{parsed.scheme}" unless VALID_SCHEMES.include?(parsed.scheme)

          # Routing context (URI query parameters, e.g. region/policy) only
          # applies to routing drivers (neo4j://). A direct bolt:// driver
          # would silently drop it — so reject it instead, matching Java's
          # IllegalArgumentException. Server Side Routing is not enabled by
          # passing a routing context to a direct connection.
          if parsed.scheme.start_with?('bolt') && !parsed.query.to_s.empty?
            raise ArgumentError,
                  "Routing parameters are not supported with scheme '#{parsed.scheme}'. Given URI: '#{uri}'"
          end
        rescue URI::InvalidURIError
          raise ArgumentError, 'Scheme must not be null'
        end
      end
    end
  end
end
