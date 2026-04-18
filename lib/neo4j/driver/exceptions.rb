# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < StandardError
        attr_reader :code, :suppressed

        def initialize(message = nil, code: nil, suppressed: [])
          super(message)
          @code = code
          @suppressed = suppressed
        end
      end

      # Client-side exceptions
      class ClientException < Neo4jException; end
      class IllegalStateException < ClientException; end
      class NoSuchRecordException < ClientException; end
      class ResultConsumedException < ClientException; end

      # Security exceptions
      class SecurityException < Neo4jException; end
      class AuthenticationException < SecurityException; end

      # Transient exceptions (can be retried)
      class TransientException < Neo4jException; end
      class ServiceUnavailableException < TransientException; end

      # Database exceptions
      class DatabaseException < Neo4jException; end
    end
  end
end
