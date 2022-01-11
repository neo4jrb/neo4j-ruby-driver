module Neo4j::Driver
  module Internal
    module Util
      class QueryKeys < Struct.new(:keys, :key_index)
        EMPTY = new([], {})
      end
    end
  end
end
