# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Returns a result's or record's column keys as symbols.
      module InternalKeys
        include ExceptionCheckable

        def keys
          check { super.map(&:to_sym) }
        end
      end
    end
  end
end
