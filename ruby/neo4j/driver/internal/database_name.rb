module Neo4j::Driver
  module Internal
    class DatabaseName
      attr_accessor :database_name, :description

      def initialize(database_name, description = nil)
        @database_name = database_name
        @description = description
      end
    end
  end
end
