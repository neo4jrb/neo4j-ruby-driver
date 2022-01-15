module Neo4j::Driver
  module Internal
    module Packstream
      class PackType
        NULL = :null
        BOOLEAN = :boolean
        INTEGER = :integer
        FLOAT = :float
        BYTES = :bytes
        STRING = :string
        LIST = :list
        MAP = :map
        STRUCT = :struct
      end
    end
  end
end
