# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalStatementResult
      include Enumerable
      include ErrorHandling

      def initialize(connection, run, pull)
        @connection = connection
        @pull = pull
        summary(run)
        @field_names = field_names
      end

      def single
        case Bolt::Connection.fetch(@connection, @pull)
        when 0
          raise Neo4j::Driver::Exceptions::NoSuchRecordException.empty
        when 1
          rec = InternalRecord.new(@field_names, @connection)
          raise Neo4j::Driver::Exceptions::NoSuchRecordException.too_many if summary(@pull).positive?
          rec
        else
          check_status(Bolt::Connection.status(@connection))
        end
      end

      def each
        yield InternalRecord.new(@field_names, @connection) while (rc = Bolt::Connection.fetch(@connection, @pull)) == 1
        check_status(Bolt::Connection.status(@connection)) if rc == -1
      end

      private

      def summary(run)
        n = Bolt::Connection.fetch_summary(@connection, run)
        return n if Bolt::Connection.summary_success(@connection) == 1
        failure = Neo4j::Driver::Value.to_ruby(Bolt::Connection.failure(@connection))
        raise Neo4j::Driver::Exceptions::ClientException.new(failure[:code], failure[:message])
      end

      def field_names
        Neo4j::Driver::Value.to_ruby(Bolt::Connection.field_names(@connection))
      end
    end
  end
end
