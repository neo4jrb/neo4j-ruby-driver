module Testkit::Backend::Messages
  module Requests
    class ExecuteQuery < Request
      def response
        Responses::EagerResult.new(fetch(driver_id).execute_query(cypher, auth_token, config, **decode(params)))
      end
    end
  end
end
