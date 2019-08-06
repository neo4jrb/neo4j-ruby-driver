# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Point2DValue
        CODE = :X
        extend StructureValue

        class << self
          def to_ruby_value(srid, x, y)
            Types::Point.new(srid: srid, x: x, y: y)
          end

          def to_neo_values(point)
            [point.srid.to_i, *point.coordinates]
          end
        end
      end
    end
  end
end
