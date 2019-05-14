# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalStatementResult
      include Enumerable
      include ErrorHandling
      include Internal::Protocol

      attr_reader :requests

      def initialize(connection, requests)
        @connection = connection
        @requests = requests
      end

      def single
        pull = process
        case Bolt::Connection.fetch(@connection, pull)
        when 0
          raise Neo4j::Driver::Exceptions::NoSuchRecordException.empty
        when 1
          rec = InternalRecord.new(@field_names, @connection)
          raise Neo4j::Driver::Exceptions::NoSuchRecordException.too_many if summary(pull).positive?
          rec
        else
          check_status(Bolt::Connection.status(@connection))
        end
      end

      def each
        pull = process
        yield InternalRecord.new(field_names, @connection) while (rc = Bolt::Connection.fetch(@connection, pull)) == 1
        check_status(Bolt::Connection.status(@connection)) if rc == -1
      end

      def consume
        process(true)
      end

      private

      def field_names
        @field_names ||= Neo4j::Driver::Value.to_ruby(Bolt::Connection.field_names(@connection))
      end
    end
  end
end
