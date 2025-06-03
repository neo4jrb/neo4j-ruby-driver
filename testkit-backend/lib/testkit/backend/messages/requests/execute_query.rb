# frozen_string_literal: true

module Testkit::Backend::Messages
  module Requests
    class ExecuteQuery < Request
      def response
        Responses::Result.new(fetch(driver_id).execute_query(cypher, auth_token, config, decode(params)))
      end

      private

      def auth_token
        config.authorizationToken
      end
    end
  end
end
