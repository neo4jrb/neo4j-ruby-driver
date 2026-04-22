# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Point (2D or 3D)
      class Point
        attr_reader :srid, :x, :y, :z

        # SRID constants for coordinate reference systems
        WGS_84_2D = 4326        # Geographic 2D (longitude, latitude)
        WGS_84_3D = 4979        # Geographic 3D (longitude, latitude, height)
        CARTESIAN_2D = 7203     # Cartesian 2D (x, y)
        CARTESIAN_3D = 9157     # Cartesian 3D (x, y, z)

        def initialize(srid: nil, x: nil, y: nil, z: nil, longitude: nil, latitude: nil, height: nil)
          # Handle longitude/latitude aliases for x/y
          if longitude || latitude
            @x = (longitude || x).to_f
            @y = (latitude || y).to_f
            @z = (height || z)&.to_f
            # Use WGS-84 SRID for geographic coordinates
            @srid = srid || (@z ? WGS_84_3D : WGS_84_2D)
          else
            @x = x.to_f
            @y = y.to_f
            @z = z&.to_f
            # Use Cartesian SRID for x/y/z coordinates
            @srid = srid || (@z ? CARTESIAN_3D : CARTESIAN_2D)
          end
        end

        def dimension
          @z.nil? ? 2 : 3
        end

        def to_s
          if @z
            "Point{srid=#{@srid}, x=#{@x}, y=#{@y}, z=#{@z}}"
          else
            "Point{srid=#{@srid}, x=#{@x}, y=#{@y}}"
          end
        end

        def ==(other)
          other.is_a?(Point) &&
            other.srid == @srid &&
            (other.x - @x).abs < 0.00001 &&
            (other.y - @y).abs < 0.00001 &&
            (@z.nil? || (other.z - @z).abs < 0.00001)
        end
      end
    end
  end
end
