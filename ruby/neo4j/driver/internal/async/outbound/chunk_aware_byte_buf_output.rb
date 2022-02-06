module Neo4j::Driver
  module Internal
    module Async
      module Outbound
        class ChunkAwareByteBufOutput
          def initialize(max_chunk_size = Connection::BoltProtocolUtil::DEFAULT_MAX_OUTBOUND_CHUNK_SIZE_BYTES)
            @max_chunk_size = verify_max_chunk_size(max_chunk_size)
          end

          def start(new_buf)
            assert_not_started
            @buf = Validator.require_non_nil!(new_buf)
            start_new_chunk(0)
          end

          def stop
            write_chunk_size_header
            @buf = nil
            @current_chunk_start_index = 0
            @current_chunk_size = 0
          end

          def write_byte(value)
            ensure_can_fit_in_current_chunk(1)
            @buf.write_byte(value)
            @current_chunk_size +=1
            self
          end

          def write_bytes(data)
            offset = 0
            length = data.length

            while offset < length
              # Ensure there is an open chunk, and that it has at least one byte of space left
              ensure_can_fit_in_current_chunk(1)

              # Write as much as we can into the current chunk
              amount_to_write = [available_bytes_in_current_chunk, length - offset].min

              @buf.write_bytes(data, offset, amount_to_write)
              @current_chunk_size += amount_to_write
              offset += amount_to_write
            end

            self
          end

          def write_short(value)
            ensure_can_fit_in_current_chunk(2)
            @buf.write_short(value)
            @current_chunk_size += 2
            self
          end

          def write_int(value)
            ensure_can_fit_in_current_chunk(4)
            @buf.write_int(value)
            @current_chunk_size += 4
            self
          end

          def write_long(value)
            ensure_can_fit_in_current_chunk(8)
            @buf.write_long(value)
            @current_chunk_size += 8
            self
          end

          def write_double(value)
            ensure_can_fit_in_current_chunk(8)
            @buf.write_double(value)
            @current_chunk_size += 8
            self
          end

          private

          def ensure_can_fit_in_current_chunk(number_of_bytes)
            target_chunk_size = @current_chunk_size + number_of_bytes
            if target_chunk_size > @max_chunk_size
              write_chunk_size_header
              start_new_chunk(@buf.write_index)
            end
          end

          def start_new_chunk(index)
            @current_chunk_start_index = index
            Connection::BoltProtocolUtil.write_empty_chunk_header(@buf)
            @current_chunk_size = Connection::BoltProtocolUtil::CHUNK_HEADER_SIZE_BYTES
          end

          def write_chunk_size_header
            # go to the beginning of the chunk and write the size header
            chunk_body_size = @current_chunk_size - Connection::BoltProtocolUtil::CHUNK_HEADER_SIZE_BYTES
            Connection::BoltProtocolUtil.writeChunkHeader( @buf, @current_chunk_start_index, chunk_body_size )
          end

          def available_bytes_in_current_chunk
            @max_chunk_size - @current_chunk_size
          end

          def assert_not_started
              raise Neo4j::Driver::Exceptions::IllegalStateException, 'Already started' if @buf
          end

          class << self
            def verify_max_chunk_size(max_chunk_size)
              if max_chunk_size <= 0
                raise Neo4j::Driver::Exceptions::IllegalArgumentException, "Max chunk size should be > 0, given: #{max_chunk_size}"
              end

              max_chunk_size
            end
          end
        end
      end
    end
  end
end
