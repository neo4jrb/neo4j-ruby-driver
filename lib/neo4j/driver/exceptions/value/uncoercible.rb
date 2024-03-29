module Neo4j
  module Driver
    module Exceptions
      module Value
        # A <em>Uncoercible</em> exception indicates that the conversion cannot be achieved.
        # @since 1.0
        class Uncoercible < ValueException
          def initialize(source_type_name, destination_type_name)
            super("Cannot coerce #{source_type_name} to #{destination_type_name}")
          end
        end
      end
    end
  end
end
