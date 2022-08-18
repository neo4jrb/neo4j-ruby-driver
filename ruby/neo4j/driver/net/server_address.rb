module Neo4j::Driver
  module Net
    module ServerAddress
      def self.of(host, port)
        Internal::BoltServerAddress.new(host: host, port: port)
      end
    end
  end
end
