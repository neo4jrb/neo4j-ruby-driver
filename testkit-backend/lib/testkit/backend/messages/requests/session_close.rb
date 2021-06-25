module Testkit::Backend::Messages
  module Requests
    class SessionClose < Request
      def process
        reference('Session')
      end

      def to_object
        delete(sessionId).tap(&:close)
      end
    end
  end
end