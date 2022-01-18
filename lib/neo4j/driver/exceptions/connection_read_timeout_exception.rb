# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Indicates that read timed out due to it taking longer than the server-supplied timeout value via the {@code connection.recv_timeout_seconds} configuration
      # hint. The server might provide this value to clients to let them know when a given connection may be considered broken if client does not get any
      # communication from the server within the specified timeout period. This results in the server being removed from the routing table.
      class ConnectionReadTimeoutException < ServiceUnavailableException
        INSTANCE = new('Connection read timed out due to it taking longer than the server-supplied timeout value via configuration hint.')

        def initialize(message)
          super(message)
        end
      end
    end
  end
end
