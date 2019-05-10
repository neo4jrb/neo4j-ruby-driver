# frozen_string_literal: true

module Neo4j
  module Driver
    class GraphDatabase
      Bolt::Lifecycle.startup

      at_exit do
        Bolt::Lifecycle.shutdown
      end

      class << self
        extend Neo4j::Driver::AutoClosable

        auto_closable :driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, config = {})
          Neo4j::Driver::InternalDriver.new(uri, auth_token)
        end
      end
    end
  end
end
