# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Exceptions::AuthenticationException do
  it 'wrong credentials' do
    expect { Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'wrong_password')) }
      .to raise_exception described_class
  end
end
