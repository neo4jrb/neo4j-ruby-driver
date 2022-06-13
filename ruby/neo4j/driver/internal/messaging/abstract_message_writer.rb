module Neo4j::Driver
  module Internal
    module Messaging
      class AbstractMessageWriter
        def initialize(packer)
          @packer = Internal::Validator.require_non_nil!(packer)
          @encoders_by_message_signature = Internal::Validator.require_non_nil!(build_encoders)
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
