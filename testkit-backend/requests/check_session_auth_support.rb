# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Whether the connected server supports per-session re-authentication
    # (Bolt 5.1+ feature). Server-side capability discovery, not driver-
    # side — the Java reference connects, inspects negotiated Bolt
    # version, and returns true for ≥ 5.1.
    #
    # DRIVER GAP: we already negotiate Bolt versions and have
    # Bolt::Connection#protocol with version constants. Adding
    # Driver#supports_session_auth? is mechanical — query the protocol
    # and return version >= 5.1. ~5 lines. Stubbed for now.
    class CheckSessionAuthSupport < Data.define(:driver_id)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'CheckSessionAuthSupport: Driver#supports_session_auth? not yet exposed (see handler comment).'
        )
      end
    end
  end
end
