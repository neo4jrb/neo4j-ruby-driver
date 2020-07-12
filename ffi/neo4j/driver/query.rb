# frozen_string_literal: true

module Neo4j
  module Driver
    class Query
      attr_reader :text, :parameters

      def initialize(text, parameters = nil)
        Internal::Validator.require_hash_parameters!(parameters)
        @text = text
        @parameters = parameters || {}
      end
    end
  end
end
