module Neo4j
  module Driver
    module Exceptions
      module Value
        # A <em>ValueException</em> indicates that the client has carried out an operation on values incorrectly.
        # @since 1.0
        class ValueException < ClientException
          def initialize(message)
            super(message)
            @serial_version_ui_d = -1269336313727174998
          end
        end
      end
    end
  end
end
