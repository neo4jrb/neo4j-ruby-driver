# frozen_string_literal: true

module Neo4j
  module Driver
    # JRuby flavour of the auth-token manager. Same Proc-based public
    # surface as the MRI sibling, but the class `include`s
    # `org.neo4j.driver.AuthTokenManager` in its body — JRuby only
    # generates the Java-side proxy at class-definition time, so a
    # retroactive include (via prepend or class_eval) doesn't produce
    # a usable interface impl. Subclasses inherit the interface, so a
    # user-written `class MyManager < Neo4j::Driver::AuthTokenManager`
    # slots into the Java driver the same as on MRI.
    #
    # The Java interface asks for `CompletionStage<AuthToken>` from
    # `getToken`; our sync Proc gets wrapped in a pre-completed future.
    # The `handleSecurityException` callback receives a Java exception
    # which we map to its Ruby counterpart before handing to the user.
    class AuthTokenManager < Internal::AuthTokenManager
      include Java::OrgNeo4jDriver::AuthTokenManager
      include Ext::ExceptionMapper

      def get_token = java.util.concurrent.CompletableFuture.completed_future(super)

      def handle_security_exception(token, exception)
        super(token, mapped_exception(exception))
      end
    end
  end
end
