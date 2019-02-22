# frozen_string_literal: true

module Neo4j
  module Driver
    class ByteArray < String
      def self.from_bytes(bytes)
        new(bytes.pack('C*'))
      end

      def to_bytes
        unpack('C*')
      end
    end
  end
end
