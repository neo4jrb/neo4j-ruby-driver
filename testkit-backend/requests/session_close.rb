# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionClose < Data.define(:session_id)
      include Request

      def execute
        registry.delete(session_id)&.close
        Response::Session.new(id: session_id)
      end
    end
  end
end
