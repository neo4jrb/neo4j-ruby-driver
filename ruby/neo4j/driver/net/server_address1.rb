module Neo4j::Driver
  module Net
    module ServerAddress1
      def self.of(host, port)
        Internal::BoltServerAddress.new(host, port)
      end
    end
  end
end
