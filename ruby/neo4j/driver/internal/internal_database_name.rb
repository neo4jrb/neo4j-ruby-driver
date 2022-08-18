module Neo4j::Driver
  module Internal
    class InternalDatabaseName < Struct.new(:database_name, :description)
      def initialize(database_name: nil, description: database_name)
        super(database_name, description)
      end
    end
  end
end
