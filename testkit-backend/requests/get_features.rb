module TestkitBackend
  module Requests
    # Per-flavour feature advertisement. testkit gates tests on these
    # strings: claim a feature and tests for it run; omit it and they
    # skip. Erring on the side of "skip" beats erring on "fail".
    #
    # The full set of testkit-known feature strings lives in
    # https://github.com/neo4j-drivers/testkit nutkit/protocol/feature.py.
    # We keep one entry per known feature here so additions / removals
    # are visible in a code review; cross-check with the Java backend's
    # COMMON_FEATURES + SYNC_FEATURES tables in GetFeatures.java.
    #
    # Tag legend (any combination):
    #   j  jruby flavour
    #   r  MRI flavour
    #   a  the Java driver itself (informational; tests are not driven
    #      from us, but it documents which features Java has so we can
    #      tell whether a missing 'jar' is a JRuby gap or a Java gap)
    class GetFeatures < Request
      FEATURES = {
        # --- Bolt versions ---------------------------------------------------
        # MRI's handshake proposes a manifest sentinel in slot 1, then
        # legacy 5.0–5.8 / 4.2–4.4 / 3.0 ranges in slots 2–4. A
        # manifest-aware server (5.7+) replies with the sentinel and
        # we negotiate via HandshakeManifestV1; older servers ignore
        # the sentinel and pick from the legacy slots.
        # 'r' (MRI) added: this branch implements the pure-Ruby Bolt 3.0
        # protocol handler (Protocol::V3) + getRoutingTable procedure
        # fallback, so MRI negotiates and passes the v3 suites too.
        'Feature:Bolt:3.0'                                  => 'jar',
        'Feature:Bolt:4.1'                                  => 'j',
        'Feature:Bolt:4.2'                                  => 'jar',
        'Feature:Bolt:4.3'                                  => 'jar',
        'Feature:Bolt:4.4'                                  => 'jar',
        'Feature:Bolt:5.0'                                  => 'jar',
        'Feature:Bolt:5.1'                                  => 'jar',
        'Feature:Bolt:5.2'                                  => 'jar',
        'Feature:Bolt:5.3'                                  => 'jar',
        'Feature:Bolt:5.4'                                  => 'jar',
        'Feature:Bolt:5.5'                                  => 'jar',
        'Feature:Bolt:5.6'                                  => 'jar',
        'Feature:Bolt:5.7'                                  => 'jar',
        'Feature:Bolt:5.8'                                  => 'jar',
        'Feature:Bolt:6.0'                                  => 'jar',
        'Feature:Bolt:6.1'                                  => '',
        'Feature:Bolt:HandshakeManifestV1'                  => 'jar',
        'Feature:Bolt:Patch:UTC'                            => 'jar',

        # --- TLS -------------------------------------------------------------
        # Bolt::TlsConfig pins the client to a min of TLS 1.2 — so
        # even if a server offered 1.1 we'd refuse to negotiate it.
        # That's the same posture modern Neo4j servers take (TLS 1.1
        # is deprecated by RFC 8996 and rejected by Aura / 5.x by
        # default), so we don't advertise 1.1 on either flavour. The
        # testkit-tls test_1_1 case then correctly asserts "connection
        # to a 1.1-only fixture must fail", which it does.
        #
        # 1.3 works under MRI's OpenSSL and Java's javax.net.ssl. The
        # JRuby docker image needs the test CAs imported into the JDK
        # truststore (Dockerfile's keytool loop) — without that the
        # +s scheme tests fail because system-trust ≠ Java-trust.
        'Feature:TLS:1.1'                                   => 'a',
        'Feature:TLS:1.2'                                   => 'jar',
        'Feature:TLS:1.3'                                   => 'jar',

        # --- Authentication --------------------------------------------------
        'Feature:Auth:Bearer'                               => 'jar',
        'Feature:Auth:Custom'                               => 'jar',
        'Feature:Auth:Kerberos'                             => 'jar',
        'Feature:Auth:Managed'                              => 'jar',
        'AuthorizationExpiredTreatment'                     => 'jar',

        # --- Public API surface ----------------------------------------------
        'Feature:API:BookmarkManager'                       => 'jar',
        'Feature:API:ConnectionAcquisitionTimeout'          => 'jar',
        'Feature:API:Driver.ExecuteQuery'                   => 'jar',
        'Feature:API:Driver.ExecuteQuery:WithAuth'          => 'jar',
        'Feature:API:Driver:GetServerInfo'                  => '',
        'Feature:API:Driver.IsEncrypted'                    => 'jar',
        'Feature:API:Driver:NotificationsConfig'            => 'jar',
        'Feature:API:Driver.VerifyAuthentication'           => 'jar',
        # JRuby's verifyConnectivity routes for the system database (the
        # bundled Java driver hardcodes it in RoutedBoltConnectionSource),
        # but testkit's routing tests expect the default database — so the
        # routing variants can't pass without reimplementing the verify
        # path. Java's own backend doesn't advertise this feature either;
        # MRI does and passes.
        'Feature:API:Driver.VerifyConnectivity'             => 'r',
        'Feature:API:Driver.SupportsSessionAuth'            => 'jar',
        'Feature:API:Driver:MaxConnectionLifetime'          => 'jar',
        'Feature:API:Liveness.Check'                        => 'jar',
        'Feature:API:Result.List'                           => 'jar',
        'Feature:API:Result.Peek'                           => 'jar',
        'Feature:API:Result.Single'                         => 'jar',
        'Feature:API:Result.SingleOptional'                 => '',
        'Feature:API:RetryableExceptions'                   => 'jar',
        'Feature:API:Session:AuthConfig'                    => 'jar',
        'Feature:API:Session:NotificationsConfig'           => 'jar',
        'Feature:API:SSLClientCertificate'                  => 'ja', # JRuby: ClientCertificateManager via DriverFactory; MRI mTLS not wired
        'Feature:API:SSLConfig'                             => 'jar',
        'Feature:API:SSLSchemes'                            => 'jar',
        'Feature:API:Summary:GqlStatusObjects'              => 'jar',
        'Feature:API:Summary:Profile:OptionalStats'         => '',
        'Feature:API:Type.Spatial'                          => '',
        'Feature:API:Type.Temporal'                         => 'jar',  # jruby wraps Java temporal types; MRI hydrates to Ruby Time/Types and defers unresolvable zone ids (Types::UnresolvableZonedDateTime)
        'Feature:API:Type.UnsupportedType'                  => 'jar',
        'Feature:API:Type.UUID'                             => '',
        'Feature:API:Type.Vector'                           => '',

        # --- Other features --------------------------------------------------
        'Feature:Impersonation'                             => 'jar',
        'Feature:IdempotentRetries'                         => 'ja',

        # --- Optimizations ---------------------------------------------------
        'Optimization:AuthPipelining'                       => 'ja',
        'Optimization:ConnectionReuse'                      => '',  # disabled in Java too
        'Optimization:EagerTransactionBegin'                => 'jar',
        'Optimization:ExecuteQueryPipelining'               => 'jar',
        'Optimization:HomeDatabaseCache'                    => 'ja',
        'Optimization:HomeDbCacheBasicPrincipalIsImpersonatedUser'  => '',
        'Optimization:ImplicitDefaultArguments'             => 'ja',
        'Optimization:MinimalBookmarksSet'                  => '',
        'Optimization:MinimalResets'                        => '',  # disabled in Java too
        'Optimization:MinimalVerifyAuthentication'          => '',
        'Optimization:PullPipelining'                       => 'jar',
        'Optimization:ResultListFetchAll'                   => 'ja',

        # --- Backend / detail ------------------------------------------------
        'Backend:MockTime'                                  => 'jar',
        # Both impls answer via Driver#routing_table(db) (returns a
        # RoutingTable — Java's on JRuby, Routing::RoutingTable on MRI);
        # how each reaches it is the driver's business, not testkit's.
        'Backend:RTFetch'                                   => 'jr',
        # Driver#routing_table_refresh(db, bookmarks). MRI forces a ROUTE
        # call; JRuby is still a no-op (Java's force-refresh needs
        # ClusterComposition parameters not yet wired from Ruby), so only
        # MRI advertises it.
        'Backend:RTForceUpdate'                             => 'r',
        'ConfHint:connection.recv_timeout_seconds'          => 'jar',
        'Detail:ClosedDriverIsEncrypted'                    => '',
        'Detail:DefaultSecurityConfigValueEquality'         => 'ja',
        'Detail:NumberIsNumber'                             => 'jr'
      }.freeze

      def process
        # Loader.jruby? reflects which driver impl Bundler actually loaded
        # (set in Driver::Loader.load(:jruby|:mri)). RUBY_PLATFORM alone
        # mismatches on JRuby[mri-flavor] CI where the loaded driver is
        # MRI even though the VM is JRuby.
        platform = Neo4j::Driver::Loader.jruby? ? 'j' : 'r'
        named_entity('FeatureList', features: FEATURES.select { |_, tag| tag.include?(platform) }.keys)
      end
    end
  end
end
