# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Exceptions::AuthenticationException do
  it 'wrong credentials' do
    Neo4j::Driver::GraphDatabase.driver(uri,
                                        Neo4j::Driver::AuthTokens.basic('neo4j', 'wrong_password'),
                                        encryption: false) do |driver|
      expect { driver.verify_connectivity }.to raise_exception described_class
      driver.close
    end
  end
end
