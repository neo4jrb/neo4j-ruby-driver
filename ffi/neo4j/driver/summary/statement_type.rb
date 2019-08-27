# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      module StatementType
        READ_ONLY = 'r'
        READ_WRITE = 'rw'
        WRITE_ONLY = 'w'
        SCHEMA_WRITE = 's'
      end
    end
  end
end
