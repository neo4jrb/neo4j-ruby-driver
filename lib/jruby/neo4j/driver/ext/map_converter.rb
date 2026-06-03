# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module MapConverter
        include PlainMapConverter

        def to_h = java_method(:asMap, [java.util.function.Function]).call(&:itself).as_ruby_object
      end
    end
  end
end
