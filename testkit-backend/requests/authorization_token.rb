# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Builds a driver auth token from a testkit AuthorizationToken
    # (basic, bearer, kerberos or custom scheme).
    class AuthorizationToken < Request
      def to_object
        case scheme
        when 'basic'
          Neo4j::Driver::AuthTokens.basic(principal, credentials, realm)
        when 'bearer', 'kerberos'
          Neo4j::Driver::AuthTokens.send(scheme, credentials)
        else
          Neo4j::Driver::AuthTokens.custom(principal, credentials, realm, scheme, parameters)
        end
      end
    end
  end
end
