module Neo4j::Driver
  module Internal
    module Messaging
      module V51
        class MessageWriterV51 < V44::MessageWriterV44
          private

          def build_encoders
            super.merge(
              LogonMessage.SIGNATURE => Encode::LogonMessageEncoder,
              LogoffMessage.SIGNATURE => Encode::LogoffMessageEncoder)
          end
        end
      end
    end
  end
end
