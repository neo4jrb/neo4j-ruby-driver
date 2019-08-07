# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalServerInfo
          attr_reader :address, :version

          def initialize(bolt_connection)
            address = Bolt::Connection.remote_endpoint(bolt_connection)
            @address = %i[host port].map { |method| Bolt::Address.send(method, address).first }.join(':')
            @version = Bolt::Connection.server(bolt_connection).first
          end
        end
      end
    end
  end
end