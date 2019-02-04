module Neo4j
  module Driver
    class Point
      attr_accessor :srid, :x, :y, :z

      def initialize(srid, x, y, z = nil)
        self.srid = srid
        self.x = x
        self.y = y
        self.z = z
      end

      def coordinates
        [x, y, z].compact
      end
    end
  end
end
