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
      # and `create_clock` (the real system clock by default). testkit's
      # subclass overrides them. Rather than leaking these into the
      # user-facing config, new_instance threads them as their own parameters
      # into the ConnectionProvider it assembles, so the Driver and the
      # user-facing `config` never carry them. `to_domain_name_resolver` is
      # identity (MRI doesn't bridge resolver types); `to_clock` wraps a
      # `#now_millis` source in Internal::ClockAdapter.
      class DriverFactory
        VALID_SCHEMES = %w[bolt bolt+s bolt+ssc neo4j neo4j+s neo4j+ssc].freeze

        def to_domain_name_resolver(resolver_proc)
          resolver_proc
        end

        # Wrap a `#now_millis` time source in the driver's Clock interface. The
        # jruby flavour wraps it in a java.time.Clock adapter instead.
        def to_clock(clock)
          Internal::ClockAdapter.new(clock)
        end

        # camelCase to match the name Java's DriverFactory exposes and that
        # subclasses (testkit's DriverFactoryWithDomainNameResolver) call
        # `super` on. Default: no custom resolver (system DNS is used). The
        # subclass returns its proc when one is registered, else falls through
        # to this via `super`.
        def getDomainNameResolver = nil

        # The clock the driver's internals run on. Default is the real system
        # clock; testkit's subclass overrides this (returning `to_clock` of its
        # own time source) so its tests can freeze/advance time — the driver
        # stays agnostic.
        def create_clock = Internal::Clock.new

        # Mutual-TLS client certificates (Feature:API:SSLClientCertificate): the
        # ClientCertificateManager is threaded into the options every connection's
        # TlsConfig reads, so each connection's SSL context presents the current
        # (rotatable) client certificate. nil (the common case) leaves TLS
        # unchanged.
        def new_instance(uri, auth_token_manager, client_certificate_manager: nil, **config)
          validate_uri(uri)
          config = config.merge(client_certificate_manager: client_certificate_manager) if client_certificate_manager
          # The factory is the single place that knows about the non-public
          # extension hooks (the domain-name resolver and the clock). It
          # assembles a fully-wired ConnectionProvider with
          # those baked in and hands it to the Driver, so the Driver and the
          # user-facing `config` never carry these hooks.
          #
          # Retain the manager (not a frozen token): the provider consults it
          # for the current token on every acquire and on security failures,
          # so token refresh / re-auth works.
          #
          # The clock the internals run on (default real, testkit's own
          # otherwise) is an internal extension hook like the domain-name
          # resolver — threaded as its own parameter to the provider / pool /
          # connection / routing / session, never mixed into the user-facing
          # `config`.
          clock = create_clock
          provider = build_connection_provider(URI(uri), auth_token_manager, config, clock)
          Driver.new(uri, config, provider, clock: clock)
        end

        private

        def build_connection_provider(uri, auth_manager, options, clock)
          klass = uri.scheme.start_with?('neo4j') ? Routing::LoadBalancer : Direct::ConnectionProvider
          klass.new(uri, auth_manager, options, domain_name_resolver: getDomainNameResolver, clock: clock)
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
