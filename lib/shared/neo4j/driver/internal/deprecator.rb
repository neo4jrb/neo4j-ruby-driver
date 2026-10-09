# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # No-op stand-in for an ActiveSupport-style deprecator; swallows the
      # `behavior=` configuration the driver would otherwise forward.
      module Deprecator
        class << self
          def deprecator
            self
          end

          def behavior=(value)
            # No-op for now
          end
        end
      end
    end
  end
end
