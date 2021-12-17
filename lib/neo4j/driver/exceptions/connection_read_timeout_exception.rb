# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class ConnectionReadTimeoutException < SecurityException
        INSTANCE = new('Connection read timed out due to it taking longer than the server-supplied timeout value via configuration hint.')
      end
    end
  end
end
