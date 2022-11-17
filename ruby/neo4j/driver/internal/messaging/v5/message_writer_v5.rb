module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        class MessageWriterV5 < AbstractMessageWriter
          def initialize(input)
            super(Common::CommonValuePacker.new(output), build_encoders)
          end

          private

          def build_encoders
            result[Request::HelloMessage::SIGNATURE] = Encode::HelloMessageEncoder.new
            result[Request::GoodbyeMessage::SIGNATURE] = Encode::GoodbyeMessageEncoder.new
            result[Request::RunWithMetadataMessage::SIGNATURE] = Encode::RunWithMetadataMessageEncoder.new
            result[Request::RouteMessage::SIGNATURE] = Encode::RouteV44MessageEncoder.new

            result[Request::DiscardMessage::SIGNATURE] = Encode::DiscardMessageEncoder.new
            result[Request::PullMessage::SIGNATURE] = Encode::PullMessageEncoder.new

            result[Request::BeginMessage::SIGNATURE] = Encode::BeginMessageEncoder.new
            result[Request::CommitMessage::SIGNATURE] = Encode::CommitMessageEncoder.new
            result[Request::RollbackMessage::SIGNATURE] = Encode::RollbackMessageEncoder.new

            result[Request::ResetMessage::SIGNATURE] = Encode::ResetMessageEncoder.new

            result
          end
        end
      end
    end
  end
end
