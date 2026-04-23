# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # The authorization info maintained on the server has expired. The client should reconnect.
      # <p>
      # Error code: Neo.ClientError.Security.AuthorizationExpired
      class AuthorizationExpiredException < SecurityException
        DESCRIPTION = 'Authorization information kept on the server has expired, this connection is no longer valid.'
      end
    end
  end
end
