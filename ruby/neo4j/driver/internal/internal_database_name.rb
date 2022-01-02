module Neo4j::Driver
  module Internal
    class InternalDatabaseName
      attr_reader :database_name
      alias description database_name

      def initialize(database_name)
        @database_name = Validator.require_non_nil!(database_name)
      end
    end
  end
end
