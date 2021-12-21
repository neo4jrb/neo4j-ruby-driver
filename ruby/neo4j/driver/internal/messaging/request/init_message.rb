module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class InitMessage
          SIGNATURE = 0x01

          attr_reader :user_agent, :auth_token

          def initialize(user_agent, auth_token)
            @user_agent = user_agent
            @auth_token = auth_token
          end

          def to_s
            ["INIT \"#{user_agent}\" {...}"]
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            !(!user_agent.nil? ? !user_agent.equals(object.user_agent) : !object.user_agent.nil?)
          end

          def hash_code
            !user_agent.nil? ? user_agent.hash_code : 0
          end
        end
      end
    end
  end
end
