module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        named_entity('FeatureList', features: [
          'Feature:API:Result.List',
          # 'Feature:API:Result.Peek',
          'Feature:API:Result.Single',
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
          # 'Feature:TLS:1.1', # probably not supported by jruby
          'Feature:TLS:1.2',
          'AuthorizationExpiredTreatment',
          # 'Optimization:ImplicitDefaultArguments', #
          # 'Optimization:MinimalResets', #
          # 'Optimization:ConnectionReuse', #
          # 'Optimization:EagerTransactionBegin', #
          'Optimization:PullPipelining',
          'ConfHint:connection.recv_timeout_seconds',
          # 'Temporary:ResultKeys', #
          'Temporary:FullSummary',
          'Temporary:CypherPathAndRelationship',
          'Temporary:TransactionClose',
          'Temporary:DriverFetchSize',
          'Temporary:DriverMaxTxRetryTime',
          'Temporary:FastFailingDiscovery',
        ])
      end
    end
  end
end
