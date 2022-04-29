module Neo4j::Driver
  module Internal
    module Messaging
      class AbstractMessageWriter
        def initialize(packer, encoders_by_message_signature)
          @packer = Internal::Validator.require_non_nil!(packer)
          @encoders_by_message_signature = Internal::Validator.require_non_nil!(encoders_by_message_signature)
        end

        def write(msg)
          signature = msg.class::SIGNATURE
          encoder = @encoders_by_message_signature[signature]

          if encoder.nil?
            raise IOError, "No encoder found for message #{msg} with signature #{signature}"
          end

          encoder.encode(msg, @packer)
        end
      end
    end
  end
end
