module Neo4j::Driver
  module Internal
    class InternalDatabaseName
      attr_reader :database_name

      def initialize(database_name)
        @database_name = java.util.Objects.require_non_null(database_name)
      end
    end
  end
end
