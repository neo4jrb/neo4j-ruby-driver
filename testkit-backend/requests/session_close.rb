module TestkitBackend
  module Requests
    class SessionClose < Request
      def process
        reference('Session')
      end

      def to_object
        delete(session_id).tap(&:close)
      end
    end
  end
end