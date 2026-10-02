# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Mixed into java.util.Map: returns it as a Ruby Hash with symbol keys
      # and recursively Ruby-ified values.
      module PlainMapConverter
        def as_ruby_object = to_h.transform_values!(&:as_ruby_object).transform_keys!(&:to_sym)
      end
    end
  end
end
