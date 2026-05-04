# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Zero-field example. Returns the static feature list.
    class GetFeatures < Data.define
      include Request

      FEATURES = %w[
        Feature:API:ConnectionAcquisitionTimeout
        Feature:API:Driver.VerifyConnectivity
        Feature:API:Result.List
        Feature:API:Result.Peek
        Feature:API:Result.Single
        Feature:Bolt:4.4
      ].freeze

      def execute
        Response::FeatureList.new(features: FEATURES)
      end
    end
  end
end
