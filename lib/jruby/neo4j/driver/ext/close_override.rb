# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Wraps the Java close() through the exception mapper. Kept separate from
      # RunOverride (which only concerns query running) so the managed
      # transaction context — DelegatingTransactionContext, exposed as
      # Neo4j::Driver::Transaction — stays run-only and does not surface a
      # close it must not expose. Included by the genuinely closeable types
      # (InternalSession, InternalTransaction).
      module CloseOverride
        include ExceptionCheckable

        def close
          check { super }
        end
      end
    end
  end
end
