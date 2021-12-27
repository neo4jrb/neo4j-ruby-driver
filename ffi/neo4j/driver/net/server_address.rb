# frozen_string_literal: true

module Neo4j
  module Driver
    module Net
      module ServerAddress
        def self.of(host, port)
          Internal::BoltServerAddress.new(host, port)
        end
      end
    end
  end
end
