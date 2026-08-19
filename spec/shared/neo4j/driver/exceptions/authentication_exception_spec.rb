# frozen_string_literal: true

# With auth enabled, Memgraph rejects wrong credentials with a ClientException (as
# the Java driver does), not Neo4j's AuthenticationException.
RSpec.describe Neo4j::Driver::Exceptions::AuthenticationException, memgraph: false do
  it 'wrong credentials' do
    Neo4j::Driver::GraphDatabase
      .driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'wrong_password')) do |driver|
      expect { driver.verify_connectivity }.to raise_exception described_class
    end
  end
end
