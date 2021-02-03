module Testkit::Backend::Messages
  module Requests
    class SessionRun < Request
      def process
        reference('Result')
      end

      def to_object
        fetch(sessionId).run(cypher, **to_params)
      end
    end
  end
end