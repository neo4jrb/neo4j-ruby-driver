module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        # FAILURE response message
        # <p>
        # Sent by the server to signal a failed operation.
        # Terminates response sequence.
        class FailureMessage < Struct.new(:code, :message)
          SIGNATURE = 0x7F
        end
      end
    end
  end
end
