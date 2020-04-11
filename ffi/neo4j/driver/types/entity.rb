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

        def ==(other)
          self.class == other.class && id == other.id
        end
      end
    end
  end
end
