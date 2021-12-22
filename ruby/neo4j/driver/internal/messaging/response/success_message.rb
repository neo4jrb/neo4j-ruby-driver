module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        # SUCCESS response message

        # <p>
        # Sent by the server to signal a successful operation.
        # Terminates response sequence.
        class SuccessMessage
          SIGNATURE = 0x70

          attr_reader :metadata

          def initialize(metadata)
            @metadata = {}
            @metadata = metadata
          end

          def to_s
            "SUCCESS #{metadata}"
          end

          def equals(obj)
            !obj.nil? && obj.class == self.class
          end

          def hash_code
            1
          end
        end
      end
    end
  end
end
