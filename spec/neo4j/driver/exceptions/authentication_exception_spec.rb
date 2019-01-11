RSpec.describe Neo4j::Driver::Exceptions::AuthenticationException do
  it 'wrong credentials' do
    expect { Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'wrong_password')) }
      .to raise_exception Neo4j::Driver::Exceptions::AuthenticationException
  end
end