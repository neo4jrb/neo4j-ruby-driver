module Neo4j::Driver
  module Internal
    module Messaging
      module BoltProtocol
        def self.for_channel(channel)
          for_version(channel.attributes[:protocol_version])
        end

        def self.for_version(version)
          case version
          when V3::BoltProtocolV3::VERSION
            V3::BoltProtocolV3::INSTANCE
          when V4::BoltProtocolV4::VERSION
            V4::BoltProtocolV4::INSTANCE
          when V41::BoltProtocolV41::VERSION
            V41::BoltProtocolV41::INSTANCE
          when V42::BoltProtocolV42::VERSION
            V42::BoltProtocolV42::INSTANCE
          when V43::BoltProtocolV43::VERSION
            V43::BoltProtocolV43::INSTANCE
          when V44::BoltProtocolV44::VERSION
            V44::BoltProtocolV44::INSTANCE
          else
            raise Exceptions::ClientException, "Unknown protocol version: #{version}"
          end
        end
      end
    end
  end
end
