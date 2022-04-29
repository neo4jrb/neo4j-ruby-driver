module Neo4j::Driver
  module Internal
    module Logging
      class ReformattedLogger
        delegate_missing_to :@delegate

        def initialize(delegate)
          @delegate = Validator.require_non_nil!(delegate)
        end

        def trace(*arg)
          debug(*arg)
        end
      end
    end
  end
end
