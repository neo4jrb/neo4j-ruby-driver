module Testkit::Backend::Messages
  module Requests
    class AuthorizationToken < Request
      def to_object
        Neo4j::Driver::AuthTokens.send(scheme, principal, credentials, realm)
      end
    end
  end
end