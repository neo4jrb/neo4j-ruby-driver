module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      FEATURES =
        {
          'Feature:API:ConnectionAcquisitionTimeout' => '',
          'Feature:API:Driver.IsEncrypted' => 'jr',
          'Feature:API:Liveness.Check' => 'j',
          'Feature:API:Result.List' => 'j',
          'Feature:API:Result.Peek' => 'j',
          'Feature:API:Result.Single' => 'j',
          'Feature:API:SessionConnectionTimeout' => '',
          'Feature:API:SSLConfig' => 'j',
          'Feature:API:SSLSchemes' => 'j',
          'Feature:API:Type.Temporal' => '',
          'Feature:API:UpdateRoutingTableTimeout' => '',
          'Feature:Auth:Bearer' => 'jr',
          'Feature:Auth:Custom' => 'jr',
          'Feature:Auth:Kerberos' => 'jr',
          'Feature:Bolt:3.0' => 'j',
          'Feature:Bolt:4.0' => 'jr',
          'Feature:Bolt:4.1' => 'j',
          'Feature:Bolt:4.2' => 'jr',
          'Feature:Bolt:4.3' => 'j',
          'Feature:Bolt:4.4' => 'j',
          'Feature:Bolt:Patch:UTC' => 'j',
          'Feature:Impersonation' => 'j',
          'Feature:TLS:1.1' => '', # TODO works for java,
          'Feature:TLS:1.2' => 'j',
          'Feature:TLS:1.3' => '', # TODO works for java
          'AuthorizationExpiredTreatment' => 'j',
          'Optimization:ConnectionReuse' => '', # disabled for java
          'Optimization:EagerTransactionBegin' => 'j',
          'Optimization:ImplicitDefaultArguments' => 'j',
          'Optimization:MinimalResets' => '', # disabled for java
          'Optimization:PullPipelining' => 'j',
          'Optimization:ResultListFetchAll' => 'j',
          'Detail:ClosedDriverIsEncrypted' => '',
          'Detail:DefaultSecurityConfigValueEquality' => 'j',
          'Detail:ResultStreamWorksAfterBrokenRecord' => '',
          'ConfHint:connection.recv_timeout_seconds' => 'j',
        }

      def process
        platform = RUBY_PLATFORM == 'java' ? 'j' : 'r'
        features_list = FEATURES.select { |_, value| value.include?(platform) }.keys
        named_entity('FeatureList', features: features_list)
      end
    end
  end
end
