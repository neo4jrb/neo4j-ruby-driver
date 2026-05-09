# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module AuthTokens
        include NeoConverter

        def basic(username, password, realm = nil)
          Neo4j::Driver::Internal::Validator.require_non_nil_credentials!(username, password)
          super
        end

        def custom(principal, credentials, realm, scheme, **parameters)
          super(principal, credentials, realm, scheme, to_neo(parameters))
        end
      end
    end
  end
end
