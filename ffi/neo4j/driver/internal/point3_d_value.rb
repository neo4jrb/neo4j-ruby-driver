# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Point3DValue
        CODE = :Y
        extend StructureValue

        class << self
          def to_ruby_value(srid, x, y, z)
            Neo4j::Driver::Types::Point.new(srid: srid, x: x, y: y, z: z)
          end

          def to_neo_values(point)
            [point.srid.to_i, *point.coordinates]
          end
        end
      end
    end
  end
end
