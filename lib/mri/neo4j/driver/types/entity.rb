# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Base for graph entities — a Node or a Relationship. Holds the shared
      # identity (id / element_id) and property map, mirroring
      # org.neo4j.driver.types.Entity, which the JRuby flavour exposes as
      # Types::Entity. Kept as a real superclass (not just to de-duplicate
      # Node/Relationship) because downstream gems and applications type-check
      # against Neo4j::Driver::Types::Entity.
      class Entity
        attr_reader :id, :element_id, :properties

        # element_id defaults to the stringified id — the Bolt 4.x wire carries
        # no element_id, and callers always expect a value (matches Java).
        def initialize(id, properties, element_id = nil)
          @id = id
          @properties = properties
          @element_id = element_id || id.to_s
        end

        # Property lookup, string- or symbol-keyed.
        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        # Entities compare by identity within their own type (a Node is never
        # equal to a Relationship), matching the Java driver.
        def ==(other)
          other.is_a?(self.class) && other.id == @id
        end
      end
    end
  end
end
