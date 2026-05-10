# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DurationNormalizer
        # Convert timeout from seconds (or ActiveSupport::Duration) to milliseconds for Bolt protocol
        def timeout_to_milliseconds(timeout) = timeout&.then { (it.to_f * 1000).round }
      end
    end
  end
end
