# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Java's UnsupportedType#message returns an Optional<String>; unwrap it to
      # a nil-or-String so the public API matches MRI's UnsupportedType, which
      # stores a plain nilable message.
      module UnsupportedType
        def message = super.or_else(nil)
      end
    end
  end
end
