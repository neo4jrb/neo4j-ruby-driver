# frozen_string_literal: true

module Neo4j
  module Driver
    module StatementRunner
      include Internal::Protocol

      def run(statement, parameters = {}, method = nil)
        puts "in StatementRunner#run"
        check_error Bolt::Connection.clear_run(@connection)
        check_error Bolt::Connection.set_run_cypher(@connection, statement, statement.size, parameters.size)
        parameters.each_with_index do |(name, object), index|
          name = name.to_s
          Value.to_neo(Bolt::Connection.set_run_cypher_parameter(@connection, index, name, name.size), object)
        end
        set_bookmarks(method) if method
        request Bolt::Connection.load_run_request(@connection)
        request Bolt::Connection.load_pull_request(@connection, -1)
        puts requests.inspect

        InternalStatementResult.new(@connection, requests)
      end
    end
  end
end
