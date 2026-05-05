module Neo4j
  module Driver
    module Exceptions
      module Value
        # A <em>NotMultiValued</em> exception indicates that the value does not consist of multiple values, a.k.a. not a map
        # or array.
        # @since 1.0
        class NotMultiValued < ValueException
        end
      end
    end
  end
end
