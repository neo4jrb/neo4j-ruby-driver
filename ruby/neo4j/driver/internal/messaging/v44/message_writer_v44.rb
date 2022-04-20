module Neo4j::Driver
  module Internal
    module Messaging
      module V44
        class MessageWriterV44 < AbstractMessageWriter
          def initialize(output)
            super(output, build_encoders)
          end

          private

          def build_encoders
            {
              Request::HelloMessage::SIGNATURE => Encode::HelloMessageEncoder.new,
              Request::GoodbyeMessage::SIGNATURE => Encode::GoodbyeMessageEncoder.new,
              Request::RunWithMetadataMessage::SIGNATURE => Encode::RunWithMetadataMessageEncoder.new,
              Request::RouteMessage::SIGNATURE => Encode::RouteMessageEncoder.new,
              Request::DiscardMessage::SIGNATURE => Encode::DiscardMessageEncoder.new,
              Request::PullMessage::SIGNATURE => Encode::PullMessageEncoder.new,
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
