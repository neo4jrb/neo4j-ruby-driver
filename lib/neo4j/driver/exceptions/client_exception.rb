# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
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
