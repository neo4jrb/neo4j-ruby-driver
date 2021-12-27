# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class BoltServerAddress
        include Net::ServerAddress

        attr_reader :host, :port

        def initialize(host, port)
          @host = host
          @port = port
        end
      end
    end
  end
end
