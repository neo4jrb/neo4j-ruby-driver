# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns ServerInfo for the connected server.
    # Driver-side gap is documented in lib/mri/neo4j/driver/driver.rb
    # at #server_info — the method raises NotImplementedError until a
    # probe-and-return is wired through.
    class GetServerInfo < Data.define(:driver_id)
      include Request

      def execute
        info = registry.fetch(driver_id).server_info
        Response::ServerInfo.new(
          address: info.address,
          agent: info.agent,
          protocol_version: info.protocol_version
        )
      end
    end
  end
end
