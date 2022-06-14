module Neo4j::Driver
  module Internal
    module Messaging
      module V4
        class MessageWriterV4 < AbstractMessageWriter
          private

          def build_encoders
            {
              Request::HelloMessage::SIGNATURE => Encode::HelloMessageEncoder.new,
              Request::GoodbyeMessage::SIGNATURE => Encode::GoodbyeMessageEncoder.new,
              Request::RunWithMetadataMessage::SIGNATURE => Encode::RunWithMetadataMessageEncoder.new,

              Request::DiscardAllMessage::SIGNATURE => Encode::DiscardAllMessageEncoder.new, # new
              Request::PullMessage::SIGNATURE => Encode::PullMessageEncoder.new, # new

              Request::BeginMessage::SIGNATURE => Encode::BeginMessageEncoder.new,
              Request::CommitMessage::SIGNATURE => Encode::CommitMessageEncoder.new,
              Request::RollbackMessage::SIGNATURE => Encode::RollbackMessageEncoder.new,

              Request::ResetMessage::SIGNATURE => Encode::ResetMessageEncoder.new,
            }
          end
        end
      end
    end
  end
end
