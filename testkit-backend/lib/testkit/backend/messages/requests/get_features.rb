module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        named_entity('FeatureList', features: [
          'Feature:API:Driver.IsEncrypted',
          'Feature:API:Result.Peek',
          'Feature:API:Result.List',
          'Feature:API:Result.Single',
          'Feature:API:Liveness.Check',
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
          'Feature:Impersonation',
          'Feature:TLS:1.1',
          'Feature:TLS:1.2',
          # 'Feature:TLS:1.3', # TODO works for java
          'AuthorizationExpiredTreatment',
          # 'Optimization:ConnectionReuse', # disabled for java
          'Optimization:EagerTransactionBegin',
          'Optimization:ImplicitDefaultArguments',
          # 'Optimization:MinimalResets', # disabled for java
          'Optimization:PullPipelining',
          'Optimization:ResultListFetchAll',
          'Detail:DefaultSecurityConfigValueEquality',
          'ConfHint:connection.recv_timeout_seconds',
        ])
      end
    end
  end
end
