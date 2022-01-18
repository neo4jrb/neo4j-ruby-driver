# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # An error has happened while getting routing table with a remote server.
      # While this error is not fatal and we might be able to recover if we continue trying on another server.
      # If we fail to get a valid routing table from all routing servers known to this driver,
      # then we will end up with a fatal error {@link ServiceUnavailableException}.

      # If you see this error in your logs, it is safe to ignore if your cluster is temporarily changing structure during that time.
      class DiscoveryException < Neo4jException
        def initialize(message, cause)
          super(message, cause)
        end
      end
    end
  end
end
