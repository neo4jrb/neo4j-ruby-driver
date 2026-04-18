# frozen_string_literal: true

module Neo4j
  module Driver
    module AuthTokens
      class << self
        def basic(username, password, realm: nil)
          token = {
            scheme: 'basic',
            principal: username,
            credentials: password
          }
          token[:realm] = realm if realm
          token
        end

        def bearer(token)
          {
            scheme: 'bearer',
            credentials: token
          }
        end

        def none
          { scheme: 'none' }
        end

        def custom(principal:, credentials:, realm: nil, scheme: 'basic', parameters: nil)
          token = {
            scheme: scheme,
            principal: principal,
            credentials: credentials
          }
          token[:realm] = realm if realm
          token[:parameters] = parameters if parameters
          token
        end
      end
    end
  end
end
