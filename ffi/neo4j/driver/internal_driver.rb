# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalDriver
      extend Neo4j::Driver::AutoClosable
      include ErrorHandling

      auto_closable :session

      def initialize(uri, auth_token)
        uri = URI(uri)
        address = Bolt::Address.create(uri.host, uri.port.to_s)
        config = Bolt::Config.create
        Bolt::Config.set_user_agent(config, 'seabolt-cmake/1.7')
        @connector = Bolt::Connector.create(address, auth_token, config)
      end

      def session(mode = AccessMode::WRITE)
        status = Bolt::Status.create
        connection = Bolt::Connector.acquire(@connector, mode, status)
        raise Exception, check_and_print_error(nil, status, 'unable to acquire connection') if connection.null?

        Neo4j::Driver::InternalSession.new(@connector, mode)
      end

      def close
        Bolt::Connector.destroy(@connector)
      end
    end
  end
end
