module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        # FAILURE response message
        # <p>
        # Sent by the server to signal a failed operation.
        # Terminates response sequence.
        class FailureMessage
          SIGNATURE = 0x7F

          attr_reader :code, :message

          def initialize(code, message)
            @code = code
            @message = message
          end

          def to_s
            "FAILURE #{code} \"#{message}\""
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            !(!code.nil? ? !code.equals(object.code) : !object.code.nil?) && !(!message.nil? ? !message.equals(object.message) : !object.message.nil?)
          end

          def hash_code
            result = !code.nil? ? code.hash_code : 0
            result = 31 * result + (!message.nil? ? message.hash_code : 0)
            result
          end
        end
      end
    end
  end
end
