# frozen_string_literal: true

module TestkitBackend
  module Internal
    # Pure-Ruby mirror of Java's `ExpirationBasedAuthTokenManager`.
    # testkit-backend uses it for `NewBasicAuthTokenManager` and
    # `NewBearerAuthTokenManager` so the bearer/basic retry semantics
    # are owned here — no need to reach into Java's internal classes
    # from testkit-backend.
    #
    # Subclasses `Neo4j::Driver::AuthTokenManager`, the impl-agnostic
    # duck-typed base. On JRuby the base already implements
    # `org.neo4j.driver.AuthTokenManager`, so this subclass slots into
    # the Java driver without any further adapter. On MRI it just
    # responds to `get_token` / `handle_security_exception`.
    #
    # Supplier returns a `{auth_token:, expires_at_ms:}` Hash. A nil
    # `expires_at_ms` means "never refresh" (encoded as the max long
    # so the bearer factory's caching short-circuit fires every call).
    class ExpirationBasedAuthTokenManager < Neo4j::Driver::AuthTokenManager
      NEVER_EXPIRES = (1 << 63) - 1

      def initialize(supplier:, retryable_exceptions:)
        @supplier = supplier
        @retryable_exceptions = retryable_exceptions
        @token = nil
        @expires_at_ms = 0
        @lock = Mutex.new
        super(
          get_token: -> { provide_token },
          handle_security_exception: ->(token, exception) { on_security_exception(token, exception) }
        )
      end

      private

      def provide_token
        @lock.synchronize do
          if @token.nil? || Neo4j::Driver::Internal::Clock.now_millis >= @expires_at_ms
            entry = @supplier.call
            @token = entry[:auth_token]
            @expires_at_ms = entry[:expires_at_ms] || NEVER_EXPIRES
          end
          @token
        end
      end

      def on_security_exception(token, exception)
        return false unless @retryable_exceptions.any? { |klass| exception.is_a?(klass) }

        @lock.synchronize { @token = nil if @token == token }
        true
      end
    end
  end
end
