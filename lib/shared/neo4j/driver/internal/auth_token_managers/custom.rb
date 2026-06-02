# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module AuthTokenManagers
        # Default implementation of the "auth token manager" duck-typed
        # protocol — anything responding to `get_token` and
        # `handle_security_exception(token, exception)` is a manager.
        # `Driver::AuthTokenManagers.custom(get_token:,
        # handle_security_exception:)` is shorthand for wrapping two
        # Procs into one of these; callers can also pass their own
        # class instance instead, with no inheritance required.
        class Custom
          def initialize(get_token, handle_security_exception)
            @get_token = get_token
            @handle_security_exception = handle_security_exception
          end

          def get_token
            @get_token.call
          end

          def handle_security_exception(token, exception)
            @handle_security_exception.call(token, exception)
          end
        end
      end
    end
  end
end
