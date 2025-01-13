module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class LogonMessage < MessageWithMetadata
          SIGNATURE = 0x6A

          def to_s = "LOGON #{safe_metadata}"
        end
      end
    end
  end
end
