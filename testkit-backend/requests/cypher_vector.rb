# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Decodes a testkit CypherVector (a dtype plus its big-endian element
    # bytes as space-separated hex pairs) into a driver Types::Vector.
    class CypherVector < Request
      def to_object
        # `data` is Request's whole-payload reader, so read the field by key.
        Neo4j::Driver::Types::Vector.from_bytes(VECTOR_ELEMENT_TYPES.fetch(dtype), [self[:data].delete(' ')].pack('H*'))
      end
    end
  end
end
