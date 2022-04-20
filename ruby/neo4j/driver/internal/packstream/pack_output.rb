module Neo4j::Driver
  module Internal
    module Packstream
      module PackOutput
        ## Produce a single byte
        def write_byte(value)
          write_value(value, 'c')
        end

        ## Produce a 4-byte signed integer
        def write_short(value)
          write_value(value, 's>')
        end

        ## Produce a 4-byte signed integer
        def write_int(value)
          write_value(value, 'l>')
        end

        ## Produce an 8-byte signed integer
        def write_long(value)
          write_value(value, 'q>')
        end

        ## Produce an 8-byte IEEE 754 "double format" floating-point number
        def write_double(value)
          write_value(value, 'G')
        end

        private

        def write_value(value, directive)
          write([value].pack(directive))
          self
        end
      end
    end
  end
end
