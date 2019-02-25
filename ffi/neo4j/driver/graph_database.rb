# frozen_string_literal: true

module Neo4j
  module Driver
    class GraphDatabase
      Bolt::Lifecycle.bolt_startup

      at_exit do
        Bolt::Lifecycle.bolt_shutdown
      end

      def self.driver(uri, auth_token, &block)
        closable = Neo4j::Driver::InternalDriver.new(uri, auth_token)
        if block
          begin
            block.arity.zero? ? closable.instance_eval(&block) : block.call(closable)
          ensure
            closable&.close
          end
        else
          closable
        end
      end
    end
  end
end
