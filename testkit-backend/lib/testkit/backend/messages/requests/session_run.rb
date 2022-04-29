module Testkit::Backend::Messages
  module Requests
    class SessionRun < Request
      def response
        Responses::Result.new(fetch(sessionId).run(cypher, to_params, to_config))
      end

      private

      def to_config
        { metadata: txMeta, timeout: timeout_duration }
      end
    end
  end
end