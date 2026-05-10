# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Creates a custom auth-token manager. The manager itself would call
    # back to testkit (via AuthTokenManagerGetAuthRequest) when the driver
    # asks it for an auth token. Until that callback machinery is wired
    # through, we just register a placeholder and ack with the id so
    # testkit can later close it.
    #
    # DRIVER GAP: needs AuthTokenManager support in Neo4j::Driver. The
    # Java reference is org.neo4j.driver.AuthTokenManager. Required pieces:
    #   - Driver accepts an :auth_token_manager option
    #   - Connection refresh calls back into the manager when a token
    #     expires
    #   - Manager's Ruby Proc rounds-trips through the testkit channel
    #     (Response::AuthTokenManagerGetAuthRequest →
    #      Request::AuthTokenManagerGetAuthCompleted)
    # The placeholder we store today is enough for testkit's lifecycle
    # plumbing only — no actual auth-manager behaviour.
    class NewAuthTokenManager < Data.define
      include Request

      def execute
        placeholder = { type: :auth_token_manager }
        Response::AuthTokenManager.new(id: registry.store(placeholder, prefix: 'authmgr'))
      end
    end
  end
end
