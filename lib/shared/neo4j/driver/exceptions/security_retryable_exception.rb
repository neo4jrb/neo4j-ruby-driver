# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A security exception the driver considers retryable: the auth-token
      # manager handled the underlying security failure (e.g. an expired
      # token), so a managed transaction may retry with a fresh token.
      # Mirrors org.neo4j.driver.exceptions.SecurityRetryableException.
      class SecurityRetryableException < SecurityException
      end
    end
  end
end
