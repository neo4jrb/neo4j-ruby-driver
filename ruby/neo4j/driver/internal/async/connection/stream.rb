module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class Stream
          include Packstream::PackInput
          include Packstream::PackOutput

          BLOCK_SIZE = 1024 * 16

          def initialize(io, block_size: BLOCK_SIZE)
            @io = io
            @block_size = block_size
            @read_buffer = String.new(encoding: Encoding::BINARY)
            @write_buffer = String.new(encoding: Encoding::BINARY)
            @eof = false
            @io.sync = true if @io.respond_to?(:sync=)
          end

          attr_reader :io

          def read(size = nil)
            return String.new(encoding: Encoding::BINARY) if size == 0

            if size
              until @eof || @read_buffer.bytesize >= size
                read_size = size - @read_buffer.bytesize
                fill_read_buffer(read_size > @block_size ? read_size : @block_size)
              end
            else
              fill_read_buffer until @eof
            end

            consume_read_buffer(size)
          end

          def read_exactly(size, exception: EOFError)
            buffer = read(size)
            raise exception, 'encountered eof while reading data' if buffer.nil?
            raise exception, 'could not read enough data' if buffer.bytesize != size
            buffer
          end

          def write(string)
            @write_buffer << string.b
            flush if @write_buffer.bytesize >= @block_size
            string.bytesize
          end

          def <<(string)
            write(string)
            self
          end

          def flush
            return if @write_buffer.empty?

            begin
              @io.write(@write_buffer)
            ensure
              @write_buffer.clear
            end
          end

          def close
            return if @io.closed?

            begin
              flush
            rescue StandardError
              # best-effort flush on close
            ensure
              @io.close
            end
          end

          def closed?
            @io.closed?
          end

          def eof?
            return false unless @read_buffer.empty?
            return true if @eof

            @io.eof?
          end

          alias eof eof?

          private

          def fill_read_buffer(size = @block_size)
            flush

            chunk = begin
              @io.readpartial(size)
            rescue EOFError
              nil
            end

            if chunk.nil? || chunk.empty?
              @eof = true
              return false
            end

            @read_buffer << chunk
            true
          end

          def consume_read_buffer(size = nil)
            return nil if @eof && @read_buffer.empty?

            if size.nil? || size >= @read_buffer.bytesize
              result = @read_buffer
              @read_buffer = String.new(encoding: Encoding::BINARY)
              result
            else
              @read_buffer.freeze
              result = @read_buffer.byteslice(0, size)
              @read_buffer = @read_buffer.byteslice(size, @read_buffer.bytesize) || String.new(encoding: Encoding::BINARY)
              result
            end
          end
        end
      end
    end
  end
end
