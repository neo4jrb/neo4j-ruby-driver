module Neo4j::Driver
  module Internal

    # The connection settings are used whenever a new connection is
    # established to a server, specifically as part of the INIT request.
    class ConnectionSettings
      attr_reader :auth_token, :user_agent, :connect_timeout_millis

      def initialize(auth_token, user_agent, connect_timeout_millis)
        @auth_token = auth_token
        @user_agent = user_agent
        @connect_timeout_millis = connect_timeout_millis
      end
    end
  end
end
