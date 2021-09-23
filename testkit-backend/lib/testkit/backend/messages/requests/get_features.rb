module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        named_entity('FeatureList', features: %w[
          AuthorizationExpiredTreatment
          Optimization:PullPipelining
          ConfHint:connection.recv_timeout_seconds
          Temporary:DriverFetchSize
          Temporary:DriverMaxTxRetryTime
          Optimization:PullPipelining
          Temporary:TransactionClose
          Temporary:ResultList
        ])
      end
    end
  end
end
