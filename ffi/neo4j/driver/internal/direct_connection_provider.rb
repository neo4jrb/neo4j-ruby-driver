# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class DirectConnectionProvider
        include ErrorHandling

        def initialize(connector)
          @connector = connector
        end

        def acquire_connection(mode)
         Async::DirectConnection.new(@connector, mode)
        end

        def verify_connectivity
          acquire_connection(AccessMode::READ).release
        end

        def close
          Bolt::Connector.destroy(@connector)
        end
      end
    end
  end
end
