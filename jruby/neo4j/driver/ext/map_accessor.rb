# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module MapAccessor
        def properties
           keys.each_with_object({}) {|key, hash| hash[key.to_sym] = self[key] }
        end

        def [](key)
          get(key.to_s).as_ruby_object
        end
      end
    end
  end
end
