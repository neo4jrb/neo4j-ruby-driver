# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # This error indicate a fatal problem to obtain routing tables such as the routing table for a specified database does not exist.
      # This exception should not be retried.
      # @since 4.0
      class FatalDiscoveryException < ClientException
      end
    end
  end
end
