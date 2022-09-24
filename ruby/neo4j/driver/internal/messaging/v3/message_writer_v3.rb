module Neo4j::Driver
  module Internal
    module Messaging
      module V3
        class MessageWriterV3 < AbstractMessageWriter
          COMMON_ENCODERS = {
            Request::HelloMessage::SIGNATURE => Encode::HelloMessageEncoder,
            Request::GoodbyeMessage::SIGNATURE => Encode::GoodbyeMessageEncoder,
            Request::RunWithMetadataMessage::SIGNATURE => Encode::RunWithMetadataMessageEncoder,
            Request::BeginMessage::SIGNATURE => Encode::BeginMessageEncoder,
            Request::CommitMessage::SIGNATURE => Encode::CommitMessageEncoder,
            Request::RollbackMessage::SIGNATURE => Encode::RollbackMessageEncoder,
            Request::ResetMessage::SIGNATURE => Encode::ResetMessageEncoder,
          }
          private

          def build_encoders
            COMMOM_ENCODERS.merge(
              Request::DiscardAllMessage::SIGNATURE => Encode::DiscardAllMessageEncoder,
              Request::PullAllMessage::SIGNATURE => Encode::PullAllMessageEncoder,
            )
          end
        end
      end
    end
  end
end
