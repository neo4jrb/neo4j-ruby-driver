# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Indicates that read timed out due to it taking longer than the server-supplied timeout value via the {@code connection.recv_timeout_seconds} configuration
      # hint. The server might provide this value to clients to let them know when a given connection may be considered broken if client does not get any
      # communication from the server within the specified timeout period. This results in the server being removed from the routing table.
      class ConnectionReadTimeoutException < ServiceUnavailableException
        MESSAGE = 'Connection read timed out due to it taking longer than the server-supplied timeout value via configuration hint.'

        # Default the message so the timeout path can build a *fresh* instance
        # per failure (`new`) instead of re-raising one shared object — a
        # shared exception accumulates/overwrites its backtrace and isn't safe
        # when several connections time out concurrently.
        def initialize(message = MESSAGE, **kwargs)
          super
        end

        # Retained for back-compat; the reader builds a fresh instance instead.
        INSTANCE = new
      end
    end
  end
end
