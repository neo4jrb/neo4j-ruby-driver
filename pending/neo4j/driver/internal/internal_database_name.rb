module Neo4j::Driver
  module Internal
    class InternalDatabaseName < Struct.new(:database_name)
      alias description database_name

      def initialize(database_name)
        super(Validator.require_non_nil!(database_name))
      end
    end
  end
end
