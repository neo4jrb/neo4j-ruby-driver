# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalKeys
        include ExceptionCheckable

        def keys
          check { super.map(&:to_sym) }
        end
      end
    end
  end
end
