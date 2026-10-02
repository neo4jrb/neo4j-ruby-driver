# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Closes the referenced session and returns a Session reference.
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
