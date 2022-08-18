module Neo4j::Driver
  module Internal
    class DatabaseNameUtil
      DEFAULT_DATABASE_NAME = nil
      SYSTEM_DATABASE_NAME = 'system'

      private

      DEFAULT_DATABASE = InternalDatabaseName.new(description: '<default database>')
      SYSTEM_DATABASE = InternalDatabaseName.new(database_name: SYSTEM_DATABASE_NAME)

      public

      class << self
        def default_database
          DEFAULT_DATABASE
        end

        def system_database
          SYSTEM_DATABASE
        end

        def database(name)
          case name
          when DEFAULT_DATABASE_NAME
            default_database
          when SYSTEM_DATABASE_NAME
            system_database
          else
            InternalDatabaseName.new(database_name: name)
          end
        end
      end
    end
  end
end

