module Neo4j::Driver
  module Internal
    module Messaging
      class AbstractMessageWriter
        def initialize(packer, encoders_by_message_signature)
          @packer = java.util.Objects.require_non_null(packer)
          @encoders_by_message_signature = java.util.Objects.require_non_null(encoders_by_message_signature)
        end

        def write(msg)
          signature = msg.signature
          encoder = @encoders_by_message_signature[signature]

          if encoder.nil?
            raise java.io.IOException, "No encoder found for message #{msg} with signature #{signature}"
          end

          encoder.encode(msg, @packer)
        end
      end
    end
  end
end
