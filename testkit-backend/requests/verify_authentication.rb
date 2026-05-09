# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Tries an auth token against the driver's connection without
    # creating a real session — i.e. "would these credentials work?".
    #
    # DRIVER GAP: needs Driver#verify_authentication(token) returning
    # true/false. Java's reference: open a fresh connection, run the
    # HELLO/LOGON sequence with the supplied token, classify the
    # outcome (security exception → false; success → true; other →
    # raise). We have HELLO support; the missing piece is wiring it as
    # a Driver-level call independent of session.
    class VerifyAuthentication < Data.define(:driver_id, :authorization_token)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'VerifyAuthentication: Driver#verify_authentication not yet implemented (see handler comment).'
        )
      end
    end
  end
end
