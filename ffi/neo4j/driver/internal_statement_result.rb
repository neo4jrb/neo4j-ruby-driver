# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalStatementResult
      include ErrorHandling
      include Conversions

      def initialize(connection, run, pull)
        @connection = connection
        @run = run
        @pull = pull
        return if success?
        raise Exception,
              check_and_print_error(@connection, Bolt::Connection.status(@connection), 'cypher execution failed')
      end

      def single
        Bolt::Connection.fetch(@connection, @pull)
        InternalRecord.new(field_names, @connection)
      end

      private

      def success?
        Bolt::Connection.fetch_summary(@connection, @run) >= 0 && Bolt::Connection.summary_success(@connection)
      end

      def field_names
        field_names = Bolt::Connection.field_names(@connection)
        Array.new(Bolt::Value.size(field_names)) do |i|
          to_string(Bolt::List.value(field_names, i), @connection)
        end
      end
    end
  end
end
