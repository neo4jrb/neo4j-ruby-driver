# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns ServerInfo for the connected server (address, agent string,
    # protocol version). Testkit uses this to gate version-specific test
    # behaviour and to validate the driver's reporting.
    #
    # DRIVER GAP: Neo4j::Driver::Driver has #verify_connectivity but no
    # public #server_info accessor. Implementing it cleanly:
    #   - Add Driver#server_info that acquires a connection (any), runs
    #     a no-op query, and returns Summary#server_info.
    #   - Or expose ServerInfo from verify_connectivity's return value
    #     (today it returns nil; java driver returns ServerInfo).
    # Testkit's expected ServerInfo fields: address, agent, protocolVersion.
    # All three are populated in our Summary#server already; the work is
    # only to surface them at the Driver level without an explicit query.
    class GetServerInfo < Data.define(:driver_id)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'GetServerInfo: Driver#server_info not yet exposed (see handler comment).'
        )
      end
    end
  end
end
