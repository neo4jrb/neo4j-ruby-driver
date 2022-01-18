# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Failed to communicate with the server due to security errors.
      # When this type of error happens, the security cause of the error should be fixed to ensure the safety of your data.
      # Restart of server/driver/cluster might be required to recover from this error.
      # @since 1.1
      class SecurityException < ClientException
        def initialize(code, message)
          super(code, message)
        end
      end
    end
  end
end
