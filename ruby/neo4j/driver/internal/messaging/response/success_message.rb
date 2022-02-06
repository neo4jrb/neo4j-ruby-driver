module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        # SUCCESS response message

        # <p>
        # Sent by the server to signal a successful operation.
        # Terminates response sequence.
        class SuccessMessage < Struct.new(:metadata)
          SIGNATURE = 0x70
        end
      end
    end
  end
end
