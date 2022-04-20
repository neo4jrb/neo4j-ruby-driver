module Neo4j::Driver
  module Internal
    module Util
      class ServerVersion < Struct.new(:product, :major, :minor, :patch)
        include Comparable
        NEO4J_PRODUCT = 'Neo4j'
        V4_4_0 = new(NEO4J_PRODUCT, 4, 4, 0)
        V4_3_0 = new(NEO4J_PRODUCT, 4, 3, 0)
        V4_2_0 = new(NEO4J_PRODUCT, 4, 2, 0)
        V4_1_0 = new(NEO4J_PRODUCT, 4, 1, 0)
        V4_0_0 = new(NEO4J_PRODUCT, 4, 0, 0)
        V3_5_0 = new(NEO4J_PRODUCT, 3, 5, 0)
        V3_4_0 = new(NEO4J_PRODUCT, 3, 4, 0)
        V_IN_DEV = new(NEO4J_PRODUCT)
        NEO4J_IN_DEV_VERSION_STRING = "#{NEO4J_PRODUCT}/dev"
        PATTERN = Regexp.new '([^/]+)/(\\d+)\\.(\\d+)(?:\\.)?(\\d*)(\\.|-|\\+)?([0-9A-Za-z\-.]*)?'

        def <=>(other)
          unless product == other.product
            raise ArgumentError, "Comparing different products #{product}  with #{other.product}"
          end
          values <=> other.values
        end

        def to_s
          major || minor || patch ? "#{product}/#{major}.#{minor}.#{patch}" : NEO4J_IN_DEV_VERSION_STRING
        end

        def self.version(server)
          PATTERN.match(server) do |matchdata|
            product = matchdata[1]
            major = matchdata[2].to_i
            minor = matchdata[3].to_i
            patch = matchdata[4].to_i
            return new(product, major, minor, patch)
          end
          return V_IN_DEV if server.casecmp?(NEO4J_IN_DEV_VERSION_STRING)
          raise ArgumentError, "Cannot parse #{server}"
        end

        def self.from_bolt_protocol_version(protocol_version)
          case protocol_version
          when Messaging::V4::BoltProtocolV4::VERSION
            V4_0_0
          when Messaging::V41::BoltProtocolV41::VERSION
            V4_1_0
          when Messaging::V42::BoltProtocolV42::VERSION
            V4_2_0
          when Messaging::V43::BoltProtocolV43::VERSION
            V4_3_0
          when Messaging::V44::BoltProtocolV44::VERSION
            V4_4_0
          else
            V_IN_DEV
          end
        end
      end
    end
  end
end
