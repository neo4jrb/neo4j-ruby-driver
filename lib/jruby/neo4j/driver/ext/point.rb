# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Adapts the Java org.neo4j.driver.types.Point interface (impls
      # InternalPoint2D / InternalPoint3D, both records) to MRI's Types::Point
      # surface, so the driver can return the Java point directly instead of
      # copying it into a Ruby object. Prepended onto the impl records — so the
      # `z` override's `super` reaches the record's own accessor — while the
      # factory below is prepended onto the interface's singleton (see
      # neo4j/driver.rb). `Types::Point` is the interface itself, so a Java point
      # already answers `is_a?(Types::Point)` with no extra wiring.
      module Point
        # SRID codes for the coordinate reference systems, matching MRI's defaults.
        WGS_84_2D = 4326    # Geographic 2D (longitude, latitude)
        WGS_84_3D = 4979    # Geographic 3D (longitude, latitude, height)
        CARTESIAN_2D = 7203 # Cartesian 2D (x, y)
        CARTESIAN_3D = 9157 # Cartesian 3D (x, y, z)

        # A 2D point reports z as NaN at the Java level; surface it as nil so a
        # 2D point reads the same as on MRI (coordinates/dimension follow from it).
        def z
          value = super
          value unless value.nan?
        end

        def coordinates
          [x, y, z].compact
        end

        def dimension
          z.nil? ? 2 : 3
        end

        # Java records compare coordinates exactly; MRI's Types::Point allows a
        # small tolerance for float round-trips. Match MRI so equality is the
        # same on both flavours.
        def ==(other)
          return false unless other.is_a?(Types::Point) && srid == other.srid

          mine = coordinates
          theirs = other.coordinates
          mine.size == theirs.size && mine.zip(theirs).all? { |left, right| (left - right).abs < 0.00001 }
        end

        # Class-level factory for `Types::Point.new(...)`, replicating MRI's
        # longitude/latitude aliases and SRID defaults, then building the Java
        # point through the driver's own Values.point. Prepended onto the Point
        # interface's singleton class (a Java interface is a bare Ruby module with
        # no `new` of its own).
        module ClassMethods
          def new(srid: nil, x: nil, y: nil, z: nil, longitude: nil, latitude: nil, height: nil)
            if longitude || latitude
              x = (longitude || x).to_f
              y = (latitude || y).to_f
              z = (height || z)&.to_f
              srid ||= z ? WGS_84_3D : WGS_84_2D
            else
              x = x.to_f
              y = y.to_f
              z = z&.to_f
              srid ||= z ? CARTESIAN_3D : CARTESIAN_2D
            end
            # *z splats to nothing when nil (2D) or a single coord (3D).
            Java::OrgNeo4jDriver::Values.point(srid, x, y, *z).as_point
          end
        end
      end
    end
  end
end
