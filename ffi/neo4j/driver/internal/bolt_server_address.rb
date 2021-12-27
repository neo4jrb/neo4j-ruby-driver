# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class BoltServerAddress
        attr_reader :host, :port

        def initialize(host, port)
          @host = host
          @port = port
        end

        def self.of(host, port)
          Internal::BoltServerAddress.new(host, port)
        end
      end
    end
  end
end
