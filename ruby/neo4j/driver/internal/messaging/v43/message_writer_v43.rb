module Neo4j::Driver
  module Internal
    module Messaging
      module V43

        # Bolt message writer v4.3
        # This version is able to encode all the versions existing on v4.2, but it encodes

        # new messages such as ROUTE
        class MessageWriterV43 < V4::MessageWriterV4
          private

          def build_encoders
            super.merge(Request::RouteMessage::SIGNATURE => Encode::RouteMessageEncoder)
          end
        end
      end
    end
  end
end
