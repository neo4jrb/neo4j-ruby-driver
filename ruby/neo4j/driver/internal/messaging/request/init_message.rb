module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class InitMessage < Struct.new(:user_agent, :auth_token)
          SIGNATURE = 0x01

          def signature
            SIGNATURE
          end

          def to_s
            "INIT \"#{user_agent}\" {...}"
          end
        end
      end
    end
  end
end
