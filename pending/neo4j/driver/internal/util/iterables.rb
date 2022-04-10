module Neo4j::Driver
  module Internal
    module Util
      class Iterables
        EMPTY_QUEUE = Queue.new

        class << self
          def single(it)
            if it.empty?
              raise ArgumentError, 'Given iterable is empty'
            end

            result = it.first

            if it.size > 1
              raise ArgumentError, "Given iterable contains more than one element: #{it}"
            end

            result
          end

          def map(alternating_key_value)
            out = {}

            (0...alternating_key_value.length).step(2) do |i|
              out[i] = out[i+1]
            end

            out
          end
        end
      end
    end
  end
end
