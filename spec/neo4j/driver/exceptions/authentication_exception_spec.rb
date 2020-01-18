# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Exceptions::AuthenticationException do
  it 'wrong credentials' do
    expect do
      Neo4j::Driver::GraphDatabase.driver(uri,
                                          Neo4j::Driver::AuthTokens.basic('neo4j', 'wrong_password'),
                                          encryption: false)
    end.to raise_exception described_class
  end
end
