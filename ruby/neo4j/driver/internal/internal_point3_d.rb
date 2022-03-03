module Neo4j::Driver
  module Internal
    class InternalPoint3D < Struct.new(:srid, :x, :y, :z)
    end
  end
end
