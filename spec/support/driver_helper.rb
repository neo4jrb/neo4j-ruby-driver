# frozen_string_literal: true

module DriverHelper
  module Helper
    mattr_accessor :single_driver

    def uri = "#{scheme}://#{address}"

    def address = "#{host}:#{port}"

    def host = ENV.fetch('TEST_NEO4J_HOST', '127.0.0.1')

    # Direct (bolt) by default — the integration suite targets a single local
    # Neo4j; the neo4j:// scheme would activate routing and require a cluster
    # (or at least an advertised_address that matches host).
    def scheme = ENV.fetch('TEST_NEO4J_SCHEME', 'bolt')

    def port = ENV.fetch('TEST_NEO4J_PORT', 7687)

    def basic_auth_token
      Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password)
    end

    def neo4j_user = ENV.fetch('TEST_NEO4J_USER', 'neo4j')

    def neo4j_password = ENV.fetch('TEST_NEO4J_PASS', 'password')

    def database = ENV.fetch('TEST_NEO4J_DATABASE', 'neo4j')

    def driver
      self.single_driver ||= Neo4j::Driver::GraphDatabase.driver(
        uri, basic_auth_token,
        max_transaction_retry_time: 2,
        connection_timeout: 3,
      # logger: ActiveSupport::Logger.new(IO::NULL, level: ::Logger::DEBUG)
      # logger: ActiveSupport::Logger.new(STDOUT, level: ::Logger::DEBUG)
      # logger: ::Logger.new(STDOUT, level: :debug)
      )
    end

    def version?(requirement)
      Gem::Requirement.create(requirement).satisfied_by?(Gem::Version.new(ENV['NEO4J_VERSION']))
    end

    def not_version?(requirement)
      !version?(requirement)
    end
  end
end
