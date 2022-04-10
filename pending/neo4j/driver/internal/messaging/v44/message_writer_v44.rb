module Neo4j::Driver
  module Internal
    module Messaging
      module V44
        class MessageWriterV44 < AbstractMessageWriter
          def initialize(output)
            super(Common::CommonValuePacker.new(output), build_encoders)
          end

          private

          def build_encoders
            result = Util::Iterables.new_hash_map_with_size(9)
            result.put(Request::HelloMessage::SIGNATURE, Encode::HelloMessageEncoder.new)
            result.put(Request::GoodbyeMessage::SIGNATURE, Encode::GoodbyeMessageEncoder.new)
            result.put(Request::RunWithMetadataMessage::SIGNATURE, Encode::RunWithMetadataMessageEncoder.new)
            result.put(Request::RouteMessage::SIGNATURE, Encode::RouteMessageEncoder.new)

            result.put(Request::DiscardMessage::SIGNATURE, Encode::DiscardMessageEncoder.new)
            result.put(Request::PullMessage::SIGNATURE, Encode::PullMessageEncoder.new)

            result.put(Request::BeginMessage::SIGNATURE, Encode::BeginMessageEncoder.new)
            result.put(Request::CommitMessage::SIGNATURE, Encode::CommitMessageEncoder.new)
            result.put(Request::RollbackMessage::SIGNATURE, Encode::RollbackMessageEncoder.new)

            result.put(Request::ResetMessage::SIGNATURE, Encode::ResetMessageEncoder.new)

            result
          end
        end
      end
    end
  end
end
