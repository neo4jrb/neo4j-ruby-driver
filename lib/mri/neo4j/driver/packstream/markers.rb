# frozen_string_literal: true

module Neo4j
  module Driver
    module PackStream
      # PackStream wire-format marker bytes.
      # See https://neo4j.com/docs/bolt/current/packstream/ for the full table.
      module Markers
        TINY_STRING = 0x80
        TINY_LIST   = 0x90
        TINY_MAP    = 0xA0
        TINY_STRUCT = 0xB0

        NULL     = 0xC0
        FLOAT_64 = 0xC1
        FALSE    = 0xC2
        TRUE     = 0xC3

        INT_8  = 0xC8
        INT_16 = 0xC9
        INT_32 = 0xCA
        INT_64 = 0xCB

        BYTES_8  = 0xCC
        BYTES_16 = 0xCD
        BYTES_32 = 0xCE

        STRING_8  = 0xD0
        STRING_16 = 0xD1
        STRING_32 = 0xD2

        LIST_8  = 0xD4
        LIST_16 = 0xD5
        LIST_32 = 0xD6

        MAP_8  = 0xD8
        MAP_16 = 0xD9
        MAP_32 = 0xDA

        STRUCT_8  = 0xDC
        STRUCT_16 = 0xDD
      end
    end
  end
end
