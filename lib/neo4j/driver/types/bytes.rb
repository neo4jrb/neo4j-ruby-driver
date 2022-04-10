# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Bytes < String
        def initialize
          super
          force_encoding(Encoding::BINARY)
        end
      end
    end
  end
end
