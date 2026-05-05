# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
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
