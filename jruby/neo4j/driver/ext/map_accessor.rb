# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module MapAccessor
        def properties
          as_map(&:as_ruby_object).to_hash.symbolize_keys
        end

        def [](key)
          get(key.to_s).as_ruby_object
        end
      end
    end
  end
end
