# frozen_string_literal: true

module Neo4j
  module Driver
    module AuthTokens
      class << self
        # Signatures mirror Java's org.neo4j.driver.AuthTokens. The JRuby
        # flavour delegates to the Java class directly, so MRI must
        # accept positional realm/scheme (not kwargs) for cross-flavour
        # parity (testkit-backend uses positional invocation).
        def basic(username, password, realm = nil)
          raise ArgumentError, "Username can't be nil" if username.nil?
          raise ArgumentError, "Password can't be nil" if password.nil?

          token = { scheme: 'basic', principal: username, credentials: password }
          token[:realm] = realm if realm
          token
        end

        def bearer(token)
          { scheme: 'bearer', credentials: token }
        end

        def kerberos(base64_encoded_ticket)
          { scheme: 'kerberos', principal: '', credentials: base64_encoded_ticket }
        end

        def none
          { scheme: 'none' }
        end

        def custom(principal, credentials, realm, scheme, parameters = {})
          token = { scheme: scheme, principal: principal, credentials: credentials }
          token[:realm] = realm if realm
          token[:parameters] = parameters unless parameters.empty?
          token
        end
      end
    end
  end
end
