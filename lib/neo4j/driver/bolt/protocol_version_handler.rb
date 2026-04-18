# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Factory for creating version-specific protocol handlers
      class ProtocolVersionHandler
        def self.for_version(connection, version_int)
          version = BoltVersion.from_int(version_int)

          case version.major
          when 3
            # Bolt 3.x not fully supported yet, treat as 4.x
            Protocol::V4.new(connection, version)
          when 4
            Protocol::V4.new(connection, version)
          when 5
            Protocol::V5.new(connection, version)
          when 6
            Protocol::V6.new(connection, version)
          else
            raise "Unsupported Bolt protocol version: #{version}"
          end
        end
      end
    end
  end
end
