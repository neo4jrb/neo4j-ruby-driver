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
              (buffer ||= ::Async::IO::Buffer.new) << @input.read_exactly(@remaining)
              size -= @remaining
              @remaining = 0
              read_exactly(size, buffer)
            else
              data = @input.read_exactly(size)
              @remaining -= size
              buffer ? buffer << data : data
            end
          end

          def ensure_termination
            raise 'Chunking problem' unless @remaining.zero? && read_length_field.zero?
          end

          private

          def read_length_field
            @input.read_exactly(2).unpack1('S>')
          end
        end
      end
    end
  end
end
