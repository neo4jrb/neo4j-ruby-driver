module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        named_entity('FeatureList', features: [
          'AuthorizationExpiredTreatment',
          # 'Optimization:ImplicitDefaultArguments', #
          # 'Optimization:MinimalResets', #
          # 'Optimization:ConnectionReuse', #
          'Optimization:PullPipelining',
          'ConfHint:connection.recv_timeout_seconds',
          # 'Temporary:ResultKeys', #
          'Temporary:FullSummary',
          # 'Temporary:CypherPathAndRelationship', #
          'Temporary:TransactionClose',
          'Temporary:DriverFetchSize',
          'Temporary:DriverMaxTxRetryTime',
          'Temporary:ResultList',
        ])
      end
    end
  end
end
