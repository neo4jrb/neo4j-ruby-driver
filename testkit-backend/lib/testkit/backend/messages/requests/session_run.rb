module Testkit::Backend::Messages
  module Requests
    class SessionRun < Request
      def process
        reference('Result')
      end

      def to_object
        fetch(sessionId).run(cypher, to_params, to_config)
      end

      def response
        Responses::Result.new(to_object)
      end

      private

      def to_config
        { metadata: txMeta, timeout: data[:timeout]&.yield_self { |it| it * 1e-3 } }
      end
    end
  end
end