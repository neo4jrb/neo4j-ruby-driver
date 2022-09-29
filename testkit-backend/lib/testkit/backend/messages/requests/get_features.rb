module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        driver_specific_features = RUBY_PLATFORM == 'java' ? jruby_features : ruby_features
        features = common_features << driver_specific_features
        named_entity('FeatureList', features: features.flatten)
      end

      def common_features
        [
          'Feature:API:Driver.IsEncrypted',
          'Feature:API:Liveness.Check',
          'Feature:API:Result.List',
          'Feature:API:Result.Peek',
          'Feature:API:Result.Single',
          'Feature:API:SSLConfig',
          'Feature:API:SSLSchemes',
          'Feature:Auth:Bearer',
          'Feature:Auth:Custom',
          'Feature:Auth:Kerberos',
          'Feature:Bolt:3.0',
          'Feature:Bolt:4.0',
          'Feature:Bolt:4.1',
          'Feature:Bolt:4.2',
          'Feature:Bolt:4.3',
          'Feature:Bolt:4.4',
          'Feature:Bolt:Patch:UTC',
          'Feature:Impersonation',
          'Feature:TLS:1.2',
          'AuthorizationExpiredTreatment',
          'Optimization:EagerTransactionBegin',
          'Optimization:ImplicitDefaultArguments',
          'Optimization:PullPipelining',
          'Optimization:ResultListFetchAll',
          'Detail:DefaultSecurityConfigValueEquality',
        ]
      end

      def jruby_features
        [
          # 'Feature:API:ConnectionAcquisitionTimeout',
          # 'Feature:API:SessionConnectionTimeout',
          # 'Feature:API:Type.Temporal',
          # 'Feature:API:UpdateRoutingTableTimeout',
          # 'Feature:TLS:1.1', # TODO works for java,
          # 'Feature:TLS:1.3', # TODO works for java
          # 'Detail:ResultStreamWorksAfterBrokenRecord',
          'ConfHint:connection.recv_timeout_seconds',
        ]
      end

      def ruby_features
        [
          # 'Optimization:ConnectionReuse', # disabled for java
          # 'Optimization:MinimalResets', # disabled for java
        ]
      end
    end
  end
end
