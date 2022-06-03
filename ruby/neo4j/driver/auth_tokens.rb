# frozen_string_literal: true

module Neo4j
  module Driver
    class AuthTokens
      class << self
        def basic(username, password, realm = nil)
          Internal::Validator.require_non_nil_credentials!(username, password)
          Internal::Security::InternalAuthToken[
            { scheme: 'basic', principal: username, credentials: password, realm: realm }.compact]
        end

        def bearer(token)
          Internal::Validator.require_non_nil!(token, "Token")
          Internal::Security::InternalAuthToken[scheme: 'bearer', credentials: token]
        end

        def kerberos(base64_encoded_ticket)
          Internal::Validator.require_non_nil!(base64_encoded_ticket, "Ticket")
          Internal::Security::InternalAuthToken[scheme: 'bearer', credentials: base64_encoded_ticket]
        end

        def custom(principal, credentials, realm, scheme, **parameters)
          Internal::Security::InternalAuthToken[{ scheme: scheme, principal: principal, credentials: credentials,
                                                  realm: realm, parameters: parameters.presence || nil }.compact]
        end

        def none
          Internal::Security::InternalAuthToken[scheme: 'none']
        end
      end
    end
  end
end
