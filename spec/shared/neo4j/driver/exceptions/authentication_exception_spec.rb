# frozen_string_literal: true

# Memgraph does not raise an AuthenticationException here (verify_connectivity
# succeeds), so this Neo4j-specific auth behavior does not apply.
RSpec.describe Neo4j::Driver::Exceptions::AuthenticationException, memgraph: false do
  it 'wrong credentials' do
    Neo4j::Driver::GraphDatabase
      .driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'wrong_password')) do |driver|
      expect { driver.verify_connectivity }.to raise_exception described_class
    end
  end
end
