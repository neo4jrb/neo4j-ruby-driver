module Neo4j::Driver
  module Internal
    class InternalPoint2D < Struct.new(:srid, :x, :y)
      def z
        Float::NAN
      end
    end
  end
end
