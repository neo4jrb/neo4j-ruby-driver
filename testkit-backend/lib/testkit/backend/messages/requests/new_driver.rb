module Testkit::Backend::Messages
  module Requests
    class NewDriver < Request
      def process
        reference('Driver')
      end

      def to_object
        Neo4j::Driver::GraphDatabase.driver(uri, Request.object_from(authorizationToken), user_agent: userAgent)
      end
    end
  end
end