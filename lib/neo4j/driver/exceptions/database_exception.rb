# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A <em>DatabaseException</em> indicates that there is a problem within the underlying database.
      # The error code provided can be used to determine further detail for the problem.
      # @since 1.0
      class DatabaseException < Neo4jException
      end
    end
  end
end
