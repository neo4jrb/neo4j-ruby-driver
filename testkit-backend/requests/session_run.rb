# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Runs an auto-commit query on the referenced session and returns a Result
    # reference.
    class SessionRun < Request
      def response
        Responses::Result.new(fetch(session_id).run(cypher, decode(params), to_config))
      end

      private

      def to_config
        { metadata: decode(tx_meta), timeout: timeout_duration }
      end
    end
  end
end
