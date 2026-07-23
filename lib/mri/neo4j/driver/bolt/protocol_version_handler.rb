# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Factory for the per-minor protocol handler matching the
      # negotiated wire version. Lookup is exact (`major.minor`)
      # because the Bolt handshake only ever returns a version the
      # server actually supports — so we don't need fuzzy matching.
      class ProtocolVersionHandler
        HANDLERS = {
          BoltVersion::V6_1.to_i => Protocol::V61,
          BoltVersion::V6_0.to_i => Protocol::V6,
          BoltVersion::V5_8.to_i => Protocol::V58,
          BoltVersion::V5_7.to_i => Protocol::V57,
          BoltVersion::V5_6.to_i => Protocol::V56,
          BoltVersion::V5_5.to_i => Protocol::V55,
          BoltVersion::V5_4.to_i => Protocol::V54,
          BoltVersion::V5_3.to_i => Protocol::V53,
          BoltVersion::V5_2.to_i => Protocol::V52,
          BoltVersion::V5_1.to_i => Protocol::V51,
          BoltVersion::V5_0.to_i => Protocol::V5,
          BoltVersion::V4_4.to_i => Protocol::V44,
          BoltVersion::V4_3.to_i => Protocol::V43,
          BoltVersion::V4_2.to_i => Protocol::V4,
          BoltVersion::V3_0.to_i => Protocol::V3
        }.freeze

        def self.for_version(connection, version_int)
          version = BoltVersion.from_int(version_int)
          klass = HANDLERS[version.to_i] ||
                  raise(Exceptions::ServiceUnavailableException,
                        "Unsupported Bolt protocol version: #{version}")
          klass.new(connection, version)
        end
      end
    end
  end
end
