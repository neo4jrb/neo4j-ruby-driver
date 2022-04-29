module Neo4j::Driver
  module Internal
    module Packstream
      module PackInput
        def read_char
          read_exactly(1)
        end

        def read_byte
          read_exactly(1).unpack1('c')
        end

        def read_ubyte
          read_exactly(1).unpack1('C')
        end

        def read_short
          read_exactly(2).unpack1('s>')
        end

        def read_ushort
          read_exactly(2).unpack1('S>')
        end

        def read_int
          read_exactly(4).unpack1('l>')
        end

        def read_uint
          read_exactly(4).unpack1('L>')
        end

        def read_long
          read_exactly(8).unpack1('q>')
        end

        def read_ulong
          read_exactly(8).unpack1('Q>')
        end

        def read_double
          read_exactly(8).unpack1('G')
        end
      end
    end
  end
end
