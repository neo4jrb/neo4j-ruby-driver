# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalDriver
      include ErrorHandling

      def initialize(uri, auth_token)
        uri = URI(uri)
        address = Bolt::Address.create(uri.host, uri.port.to_s)
        config = Bolt::Config.create
        Bolt::Config.set_user_agent(config, 'seabolt-cmake/1.7')
        @connector = Bolt::Connector.create(address, auth_token, config)
        Bolt::Address.destroy(address)
        Bolt::Values.bolt_value_destroy(auth_token)
        Bolt::Config.destroy(config)
      end

      def session
        status = Bolt::Status.create
        # connection = Bolt::Connector.acquire(@connector, :bolt_access_mode_write, status)
        connection = Bolt::Connector.acquire(@connector, 0, status)
        raise Exception, check_and_print_error(nil, status, 'unable to acquire connection') if connection.null?
        Neo4j::Driver::InternalSession.new(@connector, connection)
      ensure
        Bolt::Status.destroy(status)
      end

      def close
        Bolt::Connector.destroy(@connector)
      end
    end
  end
end
