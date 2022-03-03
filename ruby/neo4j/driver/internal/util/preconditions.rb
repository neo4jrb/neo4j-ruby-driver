module Neo4j::Driver
  module Internal
    module Util
      class Preconditions
        # Assert that given expression is true.

        # @param expression the value to check.
        # @param message the message.
        # @throws IllegalArgumentException if given value is {@code false}.
        def self.check_argument(expression, message)
          raise ArgumentError, message unless expression
        end
      end
    end
  end
end
