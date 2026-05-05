# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Success response from Neo4j server
        class Success
          attr_reader :metadata

          def initialize(metadata = {})
            @metadata = metadata
          end

          # Visitor double-dispatch: streaming consumers use this to avoid
          # `case/when` on the response class.
          def accept(visitor)
            visitor.on_success(self)
          end

          # One-shot pattern: caller expects a SUCCESS, raises otherwise.
          # Returns self so callers can chain `.metadata`.
          def assert_success!
            self
          end
        end
      end
    end
  end
end
