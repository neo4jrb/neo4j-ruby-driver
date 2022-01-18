# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # An <em>ServiceUnavailableException</em> indicates that the driver cannot communicate with the cluster.
      # @since 1.1
      class ServiceUnavailableException < Neo4jException
        def initialize(message, throwable = nil)
          super(message, throwable)
        end
      end
    end
  end
end
