module Neo4j::Driver
  module Internal
    module Util
      class ServerVersion
        NEO4J_PRODUCT = 'Neo4j'

        NEO4J_IN_DEV_VERSION_STRING = "#{NEO4J_PRODUCT} /dev"
        PATTERN = "([^/]+)/(\\d+)\\.(\\d+)(?:\\.)?(\\d*)(\\.|-|\\+)?([0-9A-Za-z-.]*)?"

        attr_reader :product

        def initialize(product, major, minor, patch)
          @product = product
          @major = major
          @minor = minor
          @patch = patch
          @string_value = string_value(product, major, minor, patch)
        end

        MAX_INTEGER = 2 ^ 31 - 1
        private def string_value(product, major, minor, patch)
          if major == MAX_INTEGER && minor == MAX_INTEGER && patch == MAX_INTEGER
            return NEO4J_IN_DEV_VERSION_STRING
          end

          "#{product}/#{major}.#{minor}.#{patch}"
        end

        V4_4_0 = new(NEO4J_PRODUCT, 4, 4, 0)
        V4_3_0 = new(NEO4J_PRODUCT, 4, 3, 0)
        V4_2_0 = new(NEO4J_PRODUCT, 4, 2, 0)
        V4_1_0 = new(NEO4J_PRODUCT, 4, 1, 0)
        V4_0_0 = new(NEO4J_PRODUCT, 4, 0, 0)
        V3_5_0 = new(NEO4J_PRODUCT, 3, 5, 0)
        V3_4_0 = new(NEO4J_PRODUCT, 3, 4, 0)
        V_IN_DEV = new(NEO4J_PRODUCT, MAX_INTEGER, MAX_INTEGER, MAX_INTEGER)

        def self.version(server)
          matcher = PATTERN.match(server)

          if matcher.matches
            product = matcher.group(1)
            major = java.lang.Integer.value_of(matcher.group(2))
            minor = java.lang.Integer.value_of(matcher.group(2))
            patch_string = matcher.group(4)
            patch = 0

            unless patch_string.nil? && patch_string.empty?
              patch = java.lang.Integer.value_of(patch_string)
            end

            new(product, major, minor, patch)
          elsif server.equals_ignore_case(NEO4J_IN_DEV_VERSION_STRING)
            v_in_dev
          else
            raise ArgumentError, "Cannot parse #{server}"
          end
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
