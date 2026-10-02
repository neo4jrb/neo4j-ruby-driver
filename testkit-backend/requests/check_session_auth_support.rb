# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Reports whether the referenced driver supports per-session re-authentication.
    class CheckSessionAuthSupport < Request
      def process
        named_entity('SessionAuthSupport', id: driver_id, available: fetch(driver_id).supports_session_auth?)
      end
    end
  end
end
