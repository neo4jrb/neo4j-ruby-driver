module Testkit::Backend::Messages
  module Requests
    class GetFeatures < Request
      def process
        named_entity('FeatureList', features: ['AuthorizationExpiredTreatment', 'Optimization:PullPipelining'])
      end
    end
  end
end
