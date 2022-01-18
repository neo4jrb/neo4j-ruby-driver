# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Failed to authenticate the driver to the server due to bad credentials provided.
      # When this error happens, the error could be recovered by closing the current driver and restart a new driver with
      # the correct credentials.

      # @since 1.1
      class AuthenticationException < SecurityException
      end
    end
  end
end
