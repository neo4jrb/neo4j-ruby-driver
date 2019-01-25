# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalStatementResult
        %i[has_next? list to_a map].each do |method|
          define_method(method) do |*args, &block|
            super(*args, &block)
          rescue Java::OrgNeo4jDriverV1Exceptions::Neo4jException => e
            e.reraise
          end
        end
      end
    end
  end
end
