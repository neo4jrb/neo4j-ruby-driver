# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Point
        attr_accessor :srid, :x, :y, :z

        SRID = {
          'WGS-84': 4326,
          'WGS-84-3D': 4979,
          cartesian: 7203,
          'cartesian-3D': 9157
        }.with_indifferent_access.freeze

        def initialize(args)
          self.x = args[:longitude] || args[:x]
          self.y = args[:latitude] || args[:y]
          self.z = args[:height] || args[:z]
          self.srid = args[:srid] || SRID[args[:crs] || implied_crs(args[:longitude] || args[:latitude])]
        end

        def coordinates
          [x, y, z].compact.map(&:to_f)
        end

        private

        def implied_crs(geo)
          if geo
            z ? :'WGS-84-3D' : :'WGS-84'
          else
            z ? :'cartesian-3D' : :cartesian
          end
        end
      end
    end
  end
end
