module Testkit::Backend::Messages
  module Requests
    class AuthorizationToken < Request
      def to_object
        Neo4j::Driver::AuthTokens.send(*auth_meth_params)
      end

      private

      def auth_meth_params
        case (scheme)
        when 'basic'
          [scheme, principal, credentials, realm]
        when 'bearer', 'kerberos'
          [scheme, credentials]
        else
          [:custom, principal, credentials, realm, scheme, parameters]
        end
      end
    end
  end
end