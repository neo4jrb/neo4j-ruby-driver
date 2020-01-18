# frozen_string_literal: true

class DriverHelper
  module Helper
    def uri
      ENV.fetch('NEO4J_BOLT_URL', 'bolt://127.0.0.1:7687')
    end

    def port
      uri.split(':').last
    end

    def basic_auth_token
      Neo4j::Driver::AuthTokens.basic('neo4j', 'password')
    end

    def driver
      @@driver ||= Neo4j::Driver::GraphDatabase.driver(
        uri, basic_auth_token,
        max_transaction_retry_time: 2,
        connection_timeout: 3,
        encryption: false
      # logger: ActiveSupport::Logger.new(IO::NULL, level: ::Logger::DEBUG)
      # logger: ActiveSupport::Logger.new(STDOUT, level: ::Logger::DEBUG)
      )
      # @@driver ||= Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.none)
    end
  end
end
