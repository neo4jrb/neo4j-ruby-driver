# frozen_string_literal: true

# Ported from neo4j-java-driver CredentialsIT.java.
RSpec.describe 'Credentials' do
  it 'is able to provide realm with basic auth' do
    Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password, 'native')) do |d|
      expect(d.session { |s| s.run('CREATE () RETURN 1').single[0] }).to eq 1
    end
  end

  it 'is able to connect with custom token' do
    token = Neo4j::Driver::AuthTokens.custom(neo4j_user, neo4j_password, 'native', 'basic')
    Neo4j::Driver::GraphDatabase.driver(uri, token) do |d|
      expect(d.session { |s| s.run('CREATE () RETURN 1').single[0] }).to eq 1
    end
  end

  it 'is able to connect with custom token with additional parameters' do
    # Positional Hash (not kwargs) so the call is identical on MRI and JRuby.
    token = Neo4j::Driver::AuthTokens.custom(neo4j_user, neo4j_password, 'native', 'basic', { secret: 16 })
    Neo4j::Driver::GraphDatabase.driver(uri, token) do |d|
      expect(d.session { |s| s.run('CREATE () RETURN 1').single[0] }).to eq 1
    end
  end

  it 'gets helpful error on invalid credentials' do
    Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(neo4j_user, 'thisisnotthepassword')) do |d|
      expect { d.session { |s| s.run('RETURN 1').consume } }
        .to raise_error(
          Neo4j::Driver::Exceptions::AuthenticationException,
          /The client is unauthorized due to authentication failure/
        )
    end
  end

  it 'routing driver fails early on wrong credentials' do
    routing_uri = "neo4j://#{host}:#{port}"
    Neo4j::Driver::GraphDatabase.driver(routing_uri, Neo4j::Driver::AuthTokens.basic(neo4j_user, 'wrongSecret')) do |d|
      expect { d.verify_connectivity }
        .to raise_error(Neo4j::Driver::Exceptions::AuthenticationException)
    end
  end
end
