module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        module ChunkDecoder
          def initialize(input)
            @input = input
            @remaining = 0
          end

          def read_exactly(size, buffer = nil)
            while @remaining.zero?
              @remaining = read_length_field
            end
            if size > @remaining
              # (buffer ||= Buffer.new(capacity: size)) << super(@remaining)
              (buffer ||= ::Async::IO::Buffer.new) << read_from_input_exactly(@remaining)
              size -= @remaining
              @remaining = 0
              read_exactly(size, buffer)
            else
              data = read_from_input_exactly(size)
              @remaining -= size
              buffer ? buffer << data : data
            end
          end

          def ensure_termination
            raise 'Chunking problem' unless @remaining.zero? && read_length_field.zero?
          end

          private

          def read_length_field
            read_from_input_exactly(2).unpack1('S>')
          end

          def read_from_input_exactly(size)
            @input.read_exactly(size, exception: Exceptions::SessionExpiredException)
          end
        end
      end
    end
  end
end
