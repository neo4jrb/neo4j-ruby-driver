module Testkit::Backend::Messages
  module Requests
    class SessionRun < Request
      def response
        Responses::Result.new(fetch(session_id).run(cypher, to_params, to_config))
      end

      private

      def to_config
        { metadata: tx_meta, timeout: timeout_duration }
      end
    end
  end
end