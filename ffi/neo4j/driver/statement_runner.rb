# frozen_string_literal: true

module Neo4j
  module Driver
    module StatementRunner
      def run(statement, parameters = {})
        check_error Bolt::Connection.set_run_cypher(@connection, statement, statement.size, parameters.size)
        parameters.each_with_index do |(name, object), index|
          name = name.to_s
          Value.to_neo(Bolt::Connection.set_run_cypher_parameter(@connection, index, name, name.size), object)
        end
        check_error Bolt::Connection.load_run_request(@connection)
        run = Bolt::Connection.last_request(@connection)

        check_error Bolt::Connection.load_pull_request(@connection, -1)
        pull_all = Bolt::Connection.last_request(@connection)

        check_error Bolt::Connection.send(@connection)

        InternalStatementResult.new(@connection, run, pull_all)
      end
    end
  end
end
