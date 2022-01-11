module Neo4j::Driver
  module Internal
    module Util
      NEO4J_PRODUCT = 'Neo4j'

      NEO4J_IN_DEV_VERSION_STRING = "#{NEO4J_PRODUCT} /dev"
      PATTERN = "([^/]+)/(\\d+)\\.(\\d+)(?:\\.)?(\\d*)(\\.|-|\\+)?([0-9A-Za-z-.]*)?"

      attr_reader :product

      def initialize(product, major, minor, patch)
        product = product
        major = major
        minor = minor
        patch = patch
        stringValue = string_value(product, major, minor, patch)
      end

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

      private def self.string_value(product, major, minor, patch)
        if major == java.lang.Integer::MAX_VALUE && minor == java.lang.Integer::MAX_VALUE && patch == java.lang.Integer::MAX_VALUE
          return NEO4J_IN_DEV_VERSION_STRING
        end

        "#{product}/#{major}.#{minor}.#{patch}"
      end

      def self.from_bolt_protocol_version(protocol_version)
        if Messaging::V4::BoltProtocolV4::VERSION.eql?(protocol_version)
          v4_0_0
        elsif Messaging::V4::BoltProtocolV4::VERSION.eql?(protocol_version)

        end
      end
    end
  end
end
