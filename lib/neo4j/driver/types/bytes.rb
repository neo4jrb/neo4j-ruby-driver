# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Bytes < String
        def initialize(str = "")
          super
          force_encoding(Encoding::BINARY)
        end
      end
    end
  end
end
