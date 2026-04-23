# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A <em>ClientException</em> indicates that the client has carried out an operation incorrectly.
      # The error code provided can be used to determine further detail for the problem.
      # @since 1.0
      class ClientException < Neo4jException
        class << self
          def unable_to_convert(object)
            raise self, "Unable to convert #{object.class.name} to Neo4j Value."
          end
        end
      end
    end
  end
end
