module Neo4j
  module Driver
    class GraphDatabase
      Bolt::Lifecycle.bolt_startup

      at_exit do
        Bolt::Lifecycle.bolt_shutdown
      end

      class << self
        def driver(uri, auth_token)
          Neo4j::Driver::InternalDriver.new(uri, auth_token)
        end
      end
    end
  end
end
