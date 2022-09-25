module Neo4j::Driver
  module Internal
    module Messaging
      module V44
        class MessageWriterV44 < V4::MessageWriterV4
          private

          def build_encoders
            super.merge(Request::RouteMessage::SIGNATURE => Encode::RouteV44MessageEncoder)
          end
        end
      end
    end
  end
end
