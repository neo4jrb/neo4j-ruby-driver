# frozen_string_literal: true

require 'active_support/core_ext/hash/keys'

module Neo4j
  module Driver
    module Ext
      module MapAccessor
        def properties
          as_map.to_hash.symbolize_keys
        end

        def [](key)
          get(key.to_s).as_ruby_object
        end
      end
    end
  end
end
