# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Entity
        attr_reader :id, :properties
        delegate :[], to: :properties

        def initialize(id, properties)
          @id = id
          @properties = properties
        end
      end
    end
  end
end
