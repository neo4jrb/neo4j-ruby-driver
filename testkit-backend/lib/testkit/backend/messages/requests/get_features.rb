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
          # 'Feature:TLS:1.1', # TODO works for java, probably not supported by jruby
          'Feature:TLS:1.2',
          'Feature:TLS:1.3', # TODO works for java
          'AuthorizationExpiredTreatment',
          # 'Optimization:ConnectionReuse', #
          'Optimization:EagerTransactionBegin',
          # 'Optimization:ImplicitDefaultArguments', # TODO works for java
          # 'Optimization:MinimalResets', #
          'Optimization:PullPipelining',
          'Optimization:ResultListFetchAll',
          'Detail:DefaultSecurityConfigValueEquality',
          'ConfHint:connection.recv_timeout_seconds',
        ])
      end
    end
  end
end
