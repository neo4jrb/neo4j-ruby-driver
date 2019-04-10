# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalSession
      include ErrorHandling

      def initialize(connector, mode)
        @connector = connector
        @mode = mode
      end

      def run(statement, parameters = {})
        connection_acquire
        check_error Bolt::Connection.set_run_cypher(@connection, statement, statement.size, parameters.size)
        parameters.each_with_index do |(name, value), index|
          # This has to be converted with `to_neo` like in the jruby based driver with a shared method
          name = name.to_s
          Bolt::Value.format_as_string(
            Bolt::Connection.set_run_cypher_parameter(@connection, index, name, name.size),
            value,
            value.size
          )
        end
        check_error Bolt::Connection.load_run_request(@connection)
        run = Bolt::Connection.last_request(@connection)

        check_error Bolt::Connection.load_pull_request(@connection, -1)
        pull_all = Bolt::Connection.last_request(@connection)

        check_error Bolt::Connection.send(@connection)

        InternalStatementResult.new(@connection, run, pull_all)
      end

      def close
        connection_release
      end

      private

      def connection_acquire
        raise Exception, "existing connection present" if @connection
        status = Bolt::Status.create
        @connection = Bolt::Connector.acquire(@connector, @mode, status)
        raise Exception, check_and_print_error(nil, status, 'unable to acquire connection') if @connection.null?
      end

      def connection_release
        Bolt::Connector.release(@connector, @connection)
        @connection = nil
      end
    end
  end
end
