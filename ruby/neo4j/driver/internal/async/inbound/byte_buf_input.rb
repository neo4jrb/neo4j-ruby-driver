module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class ByteBufInput
          attr_accessor :buf

          def start(new_buf)
            assert_not_started
            buf = java.util.Objects.require_non_null(new_buf)
          end

          def stop
            buf = nil
          end

          def read_byte
            buf.read_byte
          end

          def read_short
            buf.read_short
          end

          def read_int
            buf.read_int
          end

          def read_long
            buf.read_long
          end

          def read_double
            buf.read_double
          end

          def read_bytes(into, offset, to_read)
            buf.read_bytes(into, offset, to_read)
          end

          def peek_byte
            buf.get_byte(buf.read_index)
          end

          private

          def assert_not_started
            raise Neo4j::Driver::Exceptions::IllegalStateException, 'Already started' unless buf.nil?
          end
        end
      end
    end
  end
end
