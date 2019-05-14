# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalStatementResult
        include ExceptionCheckable

        %i[has_next? list to_a map single consume].each do |method|
          define_method(method) do |*args, &block|
            check { super(*args, &block) }
          end
        end
      end
    end
  end
end
