# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalTransaction
        include Internal::AbstractQueryRunner

        def commit
          check { super }
        end

        def rollback
          check { super }
        end
      end
    end
  end
end
