# frozen_string_literal: true

module DriverHelper
  module Helper
    mattr_accessor :single_driver

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
      self.single_driver ||= Neo4j::Driver::GraphDatabase.driver(
        uri, basic_auth_token,
        max_transaction_retry_time: 2,
        connection_timeout: 3,
        encryption: false
      # logger: ActiveSupport::Logger.new(IO::NULL, level: ::Logger::DEBUG)
      # logger: ActiveSupport::Logger.new(STDOUT, level: ::Logger::DEBUG)
      )
      # @@driver ||= Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.none)
    end

    def version?(requirement)
      Gem::Requirement.create(requirement).satisfied_by?(Gem::Version.new(ENV['NEO4J_VERSION']))
    end

    def not_version?(requirement)
      !version?(requirement)
    end
  end
end
