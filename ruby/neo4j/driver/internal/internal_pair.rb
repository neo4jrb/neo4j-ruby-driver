module Neo4j::Driver
  module Internal
    class InternalPair < Struct.new(:key, :value)
      def self.of(key, value)
        new(key, value)
      end
    end
  end
end
