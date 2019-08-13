# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Messaging
        module BoltProtocol
          def self.for_version(version)
            case version
            when V1::BoltProtocolV1::VERSION
              V1::BoltProtocolV1::INSTANCE
            when V2::BoltProtocolV2::VERSION
              V2::BoltProtocolV2::INSTANCE
            when V3::BoltProtocolV3::VERSION
              V3::BoltProtocolV3::INSTANCE
            else
              raise Exceptions::ClientException, "Unknown protocol version: #{version}"
            end
          end
        end
      end
    end
  end
end
