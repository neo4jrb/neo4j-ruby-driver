# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Statement
        def parameters
          super.as_ruby_object
        end
      end
    end
  end
end
