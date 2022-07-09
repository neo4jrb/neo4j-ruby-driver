module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class MultiDatabaseUtil
          class << self
            def assert_empty_database_name(database_name, bolt_version)
              if database_name.database_name.present?
                raise Exceptions::ClientException, "Database name parameter for selecting database is not supported in Bolt Protocol Version #{bolt_version}. Database name: '#{database_name.description}'"
              end
            end

            def supports_multi_database?(connection)
              connection.server_version >= Util::ServerVersion::V4_0_0 &&
                connection.protocol.version >= V4::BoltProtocolV4::VERSION
            end

            def supports_route_message?(connection)
              connection.protocol.version >= V43::BoltProtocolV43::VERSION
            end
          end
        end
      end
    end
  end
end
