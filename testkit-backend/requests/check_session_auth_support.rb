# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Whether the connected server supports per-session re-authentication.
    # Real impl in Driver#supports_session_auth? (probes a connection
    # and reads the protocol's supports_re_auth? flag).
    class CheckSessionAuthSupport < Data.define(:driver_id)
      include Request

      def execute
        Response::SessionAuthSupport.new(
          id: driver_id,
          available: registry.fetch(driver_id).supports_session_auth?
        )
      end
    end
  end
end
