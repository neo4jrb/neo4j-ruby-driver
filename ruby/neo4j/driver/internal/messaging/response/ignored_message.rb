module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        # IGNORED response message

        # <p>
        # Sent by the server to signal that an operation has been ignored.
        # Terminates response sequence.
        class IgnoredMessage
          SIGNATURE = 0x7E
          IGNORED = new

          def to_s
            "IGNORED {}"
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
