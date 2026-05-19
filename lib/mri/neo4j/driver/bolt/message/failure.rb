# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Failure response from Neo4j server
        class Failure
          # Code-prefix → driver exception class. Order matters: more specific
          # patterns must come first.
          EXCEPTION_FOR_CODE = [
            [%r{^Neo\.ClientError\.Security\.Unauthorized},     Exceptions::AuthenticationException],
            [%r{^Neo\.ClientError\.Security},                   Exceptions::SecurityException],
            [%r{^Neo\.ClientError\.Database\.DatabaseNotFound}, Exceptions::FatalDiscoveryException],
            [%r{^Neo\.ClientError},                             Exceptions::ClientException],
            [%r{^Neo\.TransientError},                          Exceptions::TransientException],
            [%r{^Neo\.DatabaseError},                           Exceptions::DatabaseException]
          ].freeze

          attr_reader :metadata

          def initialize(metadata)
            @metadata = metadata
          end

          def code
            @metadata[:code]
          end

          def message
            @metadata[:message]
          end

          # Map this server FAILURE to its driver-side exception class. Single
          # owner of the code→exception logic — used to live in 4+ places.
          def to_exception
            klass = EXCEPTION_FOR_CODE.find { |pattern, _| code.to_s.match?(pattern) }&.last ||
                    Exceptions::Neo4jException
            klass.new(message, code: code)
          end

          def accept(visitor)
            visitor.on_failure(self)
          end

          def assert_success!
            raise to_exception
          end
        end
      end
    end
  end
end
