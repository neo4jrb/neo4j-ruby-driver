# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Prepended onto Java's InternalTransaction: commit, rollback and run,
      # each mapping Java exceptions to the driver's Ruby ones.
      module InternalTransaction
        include Internal::AbstractQueryRunner
        include CloseOverride

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
