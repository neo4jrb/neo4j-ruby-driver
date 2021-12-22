module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        # RESET request message
        # <p>
        # Sent by clients to reset a session to a clean state - closing any open transaction or result streams.
        # This also acknowledges receipt of failures sent by the server. This is required to
        # allow optimistic sending of multiple messages before responses have been received - pipelining.
        # <p>
        # When something goes wrong, we want the server to stop processing our already sent messages,
        # but the server cannot tell the difference between what was sent before and after we saw the
        # error.
        # <p>
        # This message acts as a barrier after an error, informing the server that we've seen the error
        # message, and that messages that follow this one are safe to execute.
        class ResetMessage
          SIGNATURE = 0x0F
          RESET = new

          def to_s
            'RESET'
          end

          def signature
            SIGNATURE
          end
        end
      end
    end
  end
end
