# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A <em>TransientException</em> signals a temporary fault that may be worked around by retrying.
      # The error code provided can be used to determine further detail for the problem.
      # @since 1.0
      class TransientException < Neo4jException
        def initialize(code, message)
          super(code, message)
        end
      end
    end
  end
end
