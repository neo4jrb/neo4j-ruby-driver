module Neo4j::Driver
  module Internal
    module Security
      # A simple common token for authentication schemes that easily convert to
      # an auth token map
      class InternalAuthToken < Hash
        SCHEME_KEY = :scheme
        PRINCIPAL_KEY = :principal
        CREDENTIALS_KEY = :credentials
        REALM_KEY = :realm
        PARAMETERS_KEY = :parameters
      end
    end
  end
end
