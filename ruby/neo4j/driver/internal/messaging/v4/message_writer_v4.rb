module Neo4j::Driver
  module Internal
    module Messaging
      module V4
        class MessageWriterV4 < V3::MessageWriterV3
          private

          def build_encoders
            COMMON_ENCODERS.merge(
              Request::DiscardMessage::SIGNATURE => Encode::DiscardMessageEncoder,
              Request::PullMessage::SIGNATURE => Encode::PullMessageEncoder)
          end
        end
      end
    end
  end
end
