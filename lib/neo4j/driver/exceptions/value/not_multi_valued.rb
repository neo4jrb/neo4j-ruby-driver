module Neo4j
  module Driver
    module Exceptions
      module Value
        # A <em>NotMultiValued</em> exception indicates that the value does not consist of multiple values, a.k.a. not a map
        # or array.
        # @since 1.0
        class NotMultiValued < ValueException
          def initialize(message)
            super(message)
            @serial_version_ui_d = -7380569883011364090
          end
        end
      end
    end
  end
end
