# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module RunOverride
        include NeoConverter

        def close
          check { super }
        end

        private

        def to_statement(text, parameters)
          Neo4j::Driver::Internal::Validator.require_hash_parameters!(parameters)
          Neo4j::Driver::Query.new(text, to_neo(parameters || {}))
        end
      end
    end
  end
end
