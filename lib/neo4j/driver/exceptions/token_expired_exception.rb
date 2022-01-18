# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # The provided token has expired.
      # <p>
      # The current driver instance is considered invalid. It should not be used anymore. The client must create a new driver instance with a valid token.
      # <p>
      # Error code: Neo.ClientError.Security.TokenExpired
      class TokenExpiredException < SecurityException
      end
    end
  end
end
