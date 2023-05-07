module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      # j - jruby
      # r - MRI
      # a - java
      FEATURES =
        {
          'Feature:API:BookmarkManager' => 'a',
          'Feature:API:ConnectionAcquisitionTimeout' => 'ja',
          'Feature:API:Driver.ExecuteQuery' => 'a',
          'Feature:API:Driver:GetServerInfo' => '',
          'Feature:API:Driver.IsEncrypted' => 'jar',
          'Feature:API:Driver:NotificationsConfig' => 'ja',
          'Feature:API:Driver.VerifyAuthentication' => 'ja',
          'Feature:API:Driver.VerifyConnectivity' => '',
          'Feature:API:Driver.SupportsSessionAuth' => 'a',
          'Feature:API:Liveness.Check' => 'ja',
          'Feature:API:Result.List' => 'ja',
          'Feature:API:Result.Peek' => 'ja',
          'Feature:API:Result.Single' => 'ja',
          'Feature:API:Result.SingleOptional' => '',
          'Feature:API:Session:AuthConfig' => 'a',
          'Feature:API:Session:NotificationsConfig' => 'a',
          'Feature:API:SSLConfig' => 'ja',
          'Feature:API:SSLSchemes' => 'ja',
          'Feature:API:Type.Spatial' => '',
          'Feature:API:Type.Temporal' => 'a',
          'Feature:Auth:Bearer' => 'jar',
          'Feature:Auth:Custom' => 'jar',
          'Feature:Auth:Kerberos' => 'jar',
          'Feature:Auth:Managed' => 'a',
          'Feature:Bolt:3.0' => 'jar',
          'Feature:Bolt:4.1' => 'jar',
          'Feature:Bolt:4.2' => 'jar',
          'Feature:Bolt:4.3' => 'jar',
          'Feature:Bolt:4.4' => 'jar',
          'Feature:Bolt:5.0' => 'jar',
          'Feature:Bolt:5.1' => 'jar',
          'Feature:Bolt:5.2' => 'jar',
          'Feature:Bolt:5.3' => 'a',
          'Feature:Bolt:Patch:UTC' => 'ja',
          'Feature:Impersonation' => 'ja',
          'Feature:TLS:1.1' => 'a', # TODO works for java,
          'Feature:TLS:1.2' => 'ja',
          'Feature:TLS:1.3' => 'a', # TODO works for java
          'AuthorizationExpiredTreatment' => 'ja',
          'Optimization:ConnectionReuse' => '', # disabled for java
          'Optimization:EagerTransactionBegin' => 'ja',
          'Optimization:ImplicitDefaultArguments' => 'ja',
          'Optimization:MinimalBookmarksSet' => '',
          'Optimization:MinimalResets' => '', # disabled for java
          'Optimization:MinimalVerifyAuthentication' => '',
          'Optimization:AuthPipelining' => 'a',
          'Optimization:PullPipelining' => 'ja',
          'Optimization:ResultListFetchAll' => 'ja',
          'Detail:ClosedDriverIsEncrypted' => '',
          'Detail:DefaultSecurityConfigValueEquality' => 'ja',
          'ConfHint:connection.recv_timeout_seconds' => 'ja',
          'Backend:MockTime' => 'a',
          'Backend:RTFetch' => '',
          'Backend:RTForceUpdate' => '',
        }

      def process
        platform = RUBY_PLATFORM == 'java' ? 'j' : 'r'
        features_list = FEATURES.select { |_, value| value.include?(platform) }.keys
        named_entity('FeatureList', features: features_list)
      end
    end
  end
end
