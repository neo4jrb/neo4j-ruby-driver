# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # JRuby-only bridge from the duck-typed Ruby manager protocol
        # (any object responding to `get_token` and
        # `handle_security_exception(token, exception)`) to Java's
        # `org.neo4j.driver.AuthTokenManager` interface. Kept impl-
        # private — client code never references this; it's wrapped
        # around the user-supplied manager at the `GraphDatabase.driver`
        # boundary.
        #
        # Java requires `getToken` to return `CompletionStage<AuthToken>`,
        # so we wrap the user's sync return in a pre-completed future.
        class AuthTokenManagerAdapter
          include Java::OrgNeo4jDriver::AuthTokenManager

          def initialize(manager)
            @manager = manager
          end

          def get_token
            java.util.concurrent.CompletableFuture.completed_future(@manager.get_token)
          end

          def handle_security_exception(token, exception)
            @manager.handle_security_exception(token, exception)
          end
        end
      end
    end
  end
end
