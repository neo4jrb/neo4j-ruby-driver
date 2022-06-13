module Neo4j::Driver
  module Internal
    module Messaging
      module V43

        # Bolt message writer v4.3
        # This version is able to encode all the versions existing on v4.2, but it encodes

        # new messages such as ROUTE
        class MessageWriterV43 < AbstractMessageWriter
          private

          def build_encoders
            {
              Request::HelloMessage::SIGNATURE => Encode::HelloMessageEncoder.new,
              Request::GoodbyeMessage::SIGNATURE => Encode::GoodbyeMessageEncoder.new,
              Request::RunWithMetadataMessage::SIGNATURE => Encode::RunWithMetadataMessageEncoder.new,
              Request::RouteMessage::SIGNATURE => Encode::RouteMessageEncoder.new, # new

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
