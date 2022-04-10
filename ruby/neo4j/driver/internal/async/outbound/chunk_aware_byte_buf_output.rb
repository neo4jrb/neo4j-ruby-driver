module Neo4j::Driver
  module Internal
    module Async
      module Outbound
        class ChunkAwareByteBufOutput
          include Packstream::PackStream::Packer
          include Messaging::Common::CommonValuePacker

          class ChunkBuffer < ::Async::IO::Buffer
            include Packstream::PackOutput
            alias write <<
          end

          def initialize(output, max_chunk_size: Connection::BoltProtocolUtil::DEFAULT_MAX_OUTBOUND_CHUNK_SIZE_BYTES)
            @output = output
            @max_chunk_size = verify_max_chunk_size(max_chunk_size)
            @chunk = ChunkBuffer.new
          end

          def start
            assert_not_started
            @chunk.clear
          end

          def write_byte(value)
            ensure_can_fit_in_current_chunk(1)
            @chunk.write_byte(value)
            self
          end

          def write(data)
            offset = 0
            length = data.bytesize

            while offset < length
              # Ensure there is an open chunk, and that it has at least one byte of space left
              ensure_can_fit_in_current_chunk(1)

              # Write as much as we can into the current chunk
              amount_to_write = [available_bytes_in_current_chunk, length - offset].min

              @chunk.write(data.byteslice(offset, amount_to_write))
              offset += amount_to_write
            end

            self
          end

          def write_short(value)
            ensure_can_fit_in_current_chunk(2)
            @chunk.write_short(value)
            self
          end

          def write_int(value)
            ensure_can_fit_in_current_chunk(4)
            @chunk.write_int(value)
            self
          end

          def write_long(value)
            ensure_can_fit_in_current_chunk(8)
            @chunk.write_long(value)
            self
          end

          def write_double(value)
            ensure_can_fit_in_current_chunk(8)
            @chunk.write_double(value)
            self
          end

          def write_message_boundary
            @output.write_short(0)
          end

          def write_chunk
            @output.write_short(@chunk.bytesize)
            @output.write(@chunk)
            @chunk.clear
          end

          alias stop write_chunk

          private

          def ensure_can_fit_in_current_chunk(number_of_bytes)
            write_chunk if @chunk.bytesize + number_of_bytes > @max_chunk_size
          end

          def available_bytes_in_current_chunk
            @max_chunk_size - @chunk.bytesize
          end

          def assert_not_started
            raise Neo4j::Driver::Exceptions::IllegalStateException.new('Already started') unless @chunk.empty?
          end

          def verify_max_chunk_size(max_chunk_size)
            if max_chunk_size <= 0
              raise ArgumentError.new("Max chunk size should be > 0, given: #{max_chunk_size}")
            end

            max_chunk_size
          end
        end
      end
    end
  end
end
