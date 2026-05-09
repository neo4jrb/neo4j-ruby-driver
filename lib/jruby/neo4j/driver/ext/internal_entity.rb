# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalEntity
        include MapConverter

        alias properties to_h

        def [](key)
          get(key.to_s).as_ruby_object
        end

        def ==(other)
          java_method(:isEqual).call(other)
        end
      end
    end
  end
end
