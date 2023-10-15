# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalResult
        include Enumerable
        include ExceptionCheckable
        include InternalKeys

        %i[has_next? next single consume peek].each do |method|
          define_method(method) do |*args, &block|
            check { super(*args, &block) }
          end
        end

        def each(&block)
          check { stream.for_each(&block) }
        end
      end
    end
  end
end
