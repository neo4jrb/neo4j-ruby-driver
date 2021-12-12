module Neo4j::Driver
  module Internal
    class DatabaseNameUtil
      DEFAULT_DATABASE_NAME = nil
      SYSTEM_DATABASE_NAME = 'system'
      DEFAULT_DATABASE = DatabaseName.new(java.util.Optional.empty, "<default database>")
      SYSTEM_DATABASE = InternalDatabaseName.new(SYSTEM_DATABASE_NAME)

      def self.database(name)
        return DEFAULT_DATABASE if java.util.Objects.equals(name, DEFAULT_DATABASE_NAME)

        return SYSTEM_DATABASE if java.util.Objects.equals(name, SYSTEM_DATABASE_NAME)

        InternalDatabaseName.new(name)
      end
    end
  end
end
