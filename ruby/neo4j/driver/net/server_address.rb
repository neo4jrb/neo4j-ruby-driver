module Neo4j
  module Driver
    module Net
      module ServerAddress
        def of(host, port)
          Internal::BoltServerAddress.new(host, port)
        end
      end
    end
  end
end
