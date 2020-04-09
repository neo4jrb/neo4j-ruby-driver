# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module MapAccessor
        include MapConverter

        alias properties to_h

        def [](key)
          get(key.to_s).as_ruby_object
        end
      end
    end
  end
end
