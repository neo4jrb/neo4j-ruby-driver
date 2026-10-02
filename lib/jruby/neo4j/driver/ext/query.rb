# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Prepended onto Java's Query: returns its parameters as a Ruby Hash of
      # native values.
      module Query
        def parameters
          super.as_ruby_object
        end
      end
    end
  end
end
