# frozen_string_literal: true

module Neo4j
  module Driver
    class AuthTokens
      class << self
        def basic(username, password, realm = nil)
          Internal::Validator.require_non_nil_credentials!(username, password)
          { scheme: 'basic', principal: username, credentials: password, realm: realm }.compact
        end

        def bearer(token)
          require_non_nil!(token, "Token")
          { scheme: 'bearer', credentials: token }
        end

        def kerberos(base64_encoded_ticket)
          require_non_nil!(base64_encoded_ticket, "Ticket")
          { scheme: 'bearer', credentials: base64_encoded_ticket }
        end

        def custom(principal, credentials, realm, scheme, **parameters)
          { scheme: scheme, principal: principal, credentials: credentials, realm: realm,
            parameters: parameters.presence || nil }.compact
        end

        def none
          {}
        end
      end
    end
  end
end
