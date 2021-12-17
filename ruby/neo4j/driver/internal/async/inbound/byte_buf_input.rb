module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class ByteBufInput
          delegate :read_byte, :read_short, :read_int, :read_long, :read_double, :read_bytes, to: :@buf

          def start(new_buf)
            assert_not_started
            @buf = Validator.require_non_nil!(new_buf)
          end

          def stop
            @buf = nil
          end

          def peek_byte
            @buf.get_byte(@buf.read_index)
          end

          private

          def assert_not_started
            raise Neo4j::Driver::Exceptions::IllegalStateException, 'Already started' if @buf
          end
        end
      end
    end
  end
end
