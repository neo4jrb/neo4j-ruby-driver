module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class LogoffMessage < MessageWithMetadata
          SIGNATURE = 0x6B

          def to_s = 'LOGOFF'
        end
      end
    end
  end
end
