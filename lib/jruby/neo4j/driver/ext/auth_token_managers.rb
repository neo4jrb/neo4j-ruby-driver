# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Mirrors Java's `AuthTokenManagers.basic(Supplier<AuthToken>)` /
      # `bearer(Supplier<AuthTokenAndExpiration>)` factories with Ruby
      # keyword-arg surfaces, and adds a `custom` factory for the full
      # `AuthTokenManager` interface (get_token + handle_security_exception)
      # — the form testkit drives via `NewAuthTokenManager`. The Custom
      # class implements the Java interface directly so JRuby can pass it
      # to the driver wherever an `AuthTokenManager` is accepted.
      module AuthTokenManagers
        def basic(supplier:)
          super(supplier)
        end

        def bearer(supplier:)
          super(supplier)
        end

        def custom(get_token:, handle_security_exception:)
          Custom.new(get_token, handle_security_exception)
        end

        class Custom
          include Java::OrgNeo4jDriver::AuthTokenManager

          def initialize(get_token, handle_security_exception)
            @get_token = get_token
            @handle_security_exception = handle_security_exception
          end

          # CompletionStage<AuthToken> — our supplier is synchronous so
          # we wrap the result in a pre-completed future.
          def get_token
            java.util.concurrent.CompletableFuture.completed_future(@get_token.call)
          end

          def handle_security_exception(token, exception)
            @handle_security_exception.call(token, exception)
          end
        end
      end
    end
  end
end
