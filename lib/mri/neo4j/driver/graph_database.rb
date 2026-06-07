# frozen_string_literal: true

module Neo4j
  module Driver
    # Main entry point for creating Neo4j drivers. Wraps the supplied
    # `AuthToken` in a `StaticAuthTokenManager` and delegates the
    # actual construction to `Internal::DriverFactory#new_instance`
    # — same shape as Java's `GraphDatabase.driver(...)` →
    # `DriverFactory#newInstance(...)`.
    module GraphDatabase
      class << self
        def driver(uri, auth_token = nil, auth_token_manager: nil, **config, &block)
          mgr = auth_token_manager || Internal::Security::StaticAuthTokenManager.new(auth_token || AuthTokens.none)
          driver = Internal::DriverFactory.new.new_instance(uri, mgr, **config)

          if block_given?
            begin
              yield driver
            ensure
              driver.close
            end
          else
            driver
          end
        end
      end
    end
  end
end
