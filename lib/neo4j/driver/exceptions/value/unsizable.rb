module Neo4j
  module Driver
    module Exceptions
      module Value
        # An <em>Unsizable</em> exception indicates that the value does not have a size.
        # @since 1.0
        class Unsizable < ValueException
          def initialize(message)
            super(message)
            @serial_version_ui_d = 741487155344252339
          end
        end
      end
    end
  end
end
