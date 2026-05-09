module Neo4j
  module Driver
    module Exceptions
      module Value
        # A <em>LossyCoercion</em> exception indicates that the conversion cannot be achieved without losing precision.
        # @since 1.0
        class LossyCoercion < ValueException
          def initialize(source_type_name, destination_type_name)
            super("Cannot coerce #{source_type_name} to #{destination_type_name} without losing precision")
          end
        end
      end
    end
  end
end
