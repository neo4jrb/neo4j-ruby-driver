# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module AuthTokens
        def basic(username, password)
          Neo4j::Driver::Internal::Validator.require_non_nil_credentials!(username, password)
          super
        end
      end
    end
  end
end
