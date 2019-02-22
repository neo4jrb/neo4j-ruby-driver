# frozen_string_literal: true

module Neo4j
  module Driver
    module GraphDatabaseExt
      extend Neo4j::Driver::AutoClosable
      auto_closable :driver
    end
  end
end
