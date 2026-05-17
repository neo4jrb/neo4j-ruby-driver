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
        # MRI only handshakes 4.4 today; everything above lives on JRuby.
        'Feature:Bolt:3.0'                                  => 'ja',
        'Feature:Bolt:4.1'                                  => 'ja',
        'Feature:Bolt:4.2'                                  => 'ja',
        'Feature:Bolt:4.3'                                  => 'ja',
        'Feature:Bolt:4.4'                                  => 'jar',
        'Feature:Bolt:5.0'                                  => 'ja',
        'Feature:Bolt:5.1'                                  => 'ja',
        'Feature:Bolt:5.2'                                  => 'ja',
        'Feature:Bolt:5.3'                                  => 'ja',
        'Feature:Bolt:5.4'                                  => 'ja',
        'Feature:Bolt:5.5'                                  => 'ja',
        'Feature:Bolt:5.6'                                  => 'ja',
        'Feature:Bolt:5.7'                                  => 'ja',
        'Feature:Bolt:5.8'                                  => 'ja',
        'Feature:Bolt:6.0'                                  => 'ja',
        'Feature:Bolt:HandshakeManifestV1'                  => 'ja',
        'Feature:Bolt:Patch:UTC'                            => 'ja',

        # --- TLS -------------------------------------------------------------
        'Feature:TLS:1.1'                                   => 'a',  # works on Java; not yet on Ruby
        'Feature:TLS:1.2'                                   => 'ja',
        'Feature:TLS:1.3'                                   => 'a',  # works on Java; not yet on Ruby

        # --- Authentication --------------------------------------------------
        'Feature:Auth:Bearer'                               => 'jar',
        'Feature:Auth:Custom'                               => 'jar',
        'Feature:Auth:Kerberos'                             => 'jar',
        'Feature:Auth:Managed'                              => 'a',
        'AuthorizationExpiredTreatment'                     => 'ja',

        # --- Public API surface ----------------------------------------------
        'Feature:API:BookmarkManager'                       => 'a',
        'Feature:API:ConnectionAcquisitionTimeout'          => 'ja',
        'Feature:API:Driver.ExecuteQuery'                   => 'ja',
        'Feature:API:Driver:GetServerInfo'                  => '',
        'Feature:API:Driver.IsEncrypted'                    => 'jar',
        'Feature:API:Driver:NotificationsConfig'            => 'ja',
        'Feature:API:Driver.VerifyAuthentication'           => 'ja',
        'Feature:API:Driver.VerifyConnectivity'             => 'jr',
        'Feature:API:Driver.SupportsSessionAuth'            => 'ja',
        'Feature:API:Driver:MaxConnectionLifetime'          => 'a',
        'Feature:API:Liveness.Check'                        => 'ja',
        'Feature:API:Result.List'                           => 'jar',
        'Feature:API:Result.Peek'                           => 'jar',
        'Feature:API:Result.Single'                         => 'jar',
        'Feature:API:Result.SingleOptional'                 => '',
        'Feature:API:RetryableExceptions'                   => '',
        'Feature:API:Session:AuthConfig'                    => 'a',
        'Feature:API:Session:NotificationsConfig'           => 'a',
        'Feature:API:SSLClientCertificate'                  => 'a',
        'Feature:API:SSLConfig'                             => 'ja',
        'Feature:API:SSLSchemes'                            => 'ja',
        'Feature:API:Summary:GqlStatusObjects'              => 'a',
        'Feature:API:Type.Spatial'                          => '',
        'Feature:API:Type.Temporal'                         => 'a',  # most pass on Java; subtest gating still missing on Ruby
        'Feature:API:Type.UnsupportedType'                  => 'a',
        'Feature:API:Type.Vector'                           => '',

        # --- Other features --------------------------------------------------
        'Feature:Impersonation'                             => 'ja',
        'Feature:IdempotentRetries'                         => '',

        # --- Optimizations ---------------------------------------------------
        'Optimization:AuthPipelining'                       => 'a',
        'Optimization:ConnectionReuse'                      => '',  # disabled in Java too
        'Optimization:EagerTransactionBegin'                => 'ja',
        'Optimization:ExecuteQueryPipelining'               => 'a',
        'Optimization:HomeDatabaseCache'                    => 'a',
        'Optimization:ImplicitDefaultArguments'             => 'ja',
        'Optimization:MinimalBookmarksSet'                  => '',
        'Optimization:MinimalResets'                        => '',  # disabled in Java too
        'Optimization:PullPipelining'                       => 'ja',
        'Optimization:ResultListFetchAll'                   => 'ja',

        # --- Backend / detail ------------------------------------------------
        'Backend:MockTime'                                  => 'a',
        # MRI: routes through driver.session_factory.connection_provider
        # .routing_table_registry.routing_table_handler(db).routing_table —
        # mirrors Java's internal API on top of Routing::LoadBalancer.
        # JRuby: uses Java's getRoutingTableHandler via the
        # RoutingTableRegistryImpl extension.
        'Backend:RTFetch'                                   => 'jr',
        # MRI: registry.refresh forces a ROUTE call.
        # JRuby: ForcedRoutingTableUpdate is still a no-op (Java's
        # force-refresh needs ClusterComposition parameters not yet
        # wired from Ruby). Don't advertise until that's done.
        'Backend:RTForceUpdate'                             => 'r',
        'ConfHint:connection.recv_timeout_seconds'          => 'ja',
        'Detail:ClosedDriverIsEncrypted'                    => '',
        'Detail:DefaultSecurityConfigValueEquality'         => 'ja',
        'Detail:NumberIsNumber'                             => 'jar'
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
