# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Wraps the Java Result as a Ruby Enumerable, mapping exceptions on every
      # traversal (next/peek/consume/single/each/to_a).
      module InternalResult
        include Enumerable
        include ExceptionCheckable
        include InternalKeys

        %i[has_next? next single consume peek].each do |method|
          define_method(method) do |*args, &block|
            check { super(*args, &block) }
          end
        end

        def each(&)
          check { stream.for_each(&) }
        end

        def to_a
          check { list.to_a }
        end
      end
    end
  end
end
