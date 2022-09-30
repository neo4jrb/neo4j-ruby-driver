module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        platform = RUBY_PLATFORM == 'java' ? 'jruby' : 'ruby'
        features_list = features.select{|key, value| value == 'all' || value == platform}.keys
        named_entity('FeatureList', features: features_list.flatten)
      end

      def features
        {
          'Feature:API:Driver.IsEncrypted' => 'all',
          'Feature:API:Liveness.Check' => 'all',
          'Feature:API:Result.List' => 'all',
          'Feature:API:Result.Peek' => 'all',
          'Feature:API:Result.Single' => 'all',
          'Feature:API:SSLConfig' => 'all',
          'Feature:API:SSLSchemes' => 'all',
          'Feature:Auth:Bearer' => 'all',
          'Feature:Auth:Custom' => 'all',
          'Feature:Auth:Kerberos' => 'all',
          'Feature:Bolt:3.0' => 'all',
          'Feature:Bolt:4.0' => 'all',
          'Feature:Bolt:4.1' => 'all',
          'Feature:Bolt:4.2' => 'all',
          'Feature:Bolt:4.3' => 'all',
          'Feature:Bolt:4.4' => 'all',
          'Feature:Bolt:Patch:UTC' => 'all',
          'Feature:Impersonation' => 'all',
          'Feature:TLS:1.2' => 'all',
          'AuthorizationExpiredTreatment' => 'all',
          'Optimization:EagerTransactionBegin' => 'all',
          'Optimization:ImplicitDefaultArguments' => 'all',
          'Optimization:PullPipelining' => 'all',
          'Optimization:ResultListFetchAll' => 'all',
          'Detail:DefaultSecurityConfigValueEquality' => 'all',
          'Feature:API:ConnectionAcquisitionTimeout' => 'none',
          'Feature:API:SessionConnectionTimeout' => 'none',
          'Feature:API:Type.Temporal' => 'none',
          'Feature:API:UpdateRoutingTableTimeout' => 'none',
          'Feature:TLS:1.1' => 'none', # TODO works for java
          'Feature:TLS:1.3' => 'none', # TODO works for java
          'Detail:ResultStreamWorksAfterBrokenRecord' => 'none',
          'ConfHint:connection.recv_timeout_seconds' => 'jruby',
          'Optimization:ConnectionReuse' => 'none', # disabled for java
          'Optimization:MinimalResets' => 'none' # disabled for java
        }
      end
    end
  end
end
