module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class RollbackMessage
          SIGNATURE = 0x13
          ROLLBACK = new

          def signature
            SIGNATURE
          end

          def to_s
            'ROLLBACK'
          end
        end
      end
    end
  end
end
