# frozen_string_literal: true

RSpec.describe 'DirectDriverSpec' do
  it 'allows IPv6 address', async_io: true do
    Neo4j::Driver::GraphDatabase
      .driver("bolt://[::1]:#{port}", basic_auth_token) do |driver|
      # verifying address is implementation dependent and goes beyond integration testing
    end
  end

  it 'rejects invalid address', async_io: true do
    expect { Neo4j::Driver::GraphDatabase.driver('*', basic_auth_token) }
      .to raise_error ArgumentError, 'Scheme must not be null'
  end

  it 'registers single server', async_io: true do
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token) do |driver|
      # verifying address is implementation dependent and goes beyond integration testing
    end
  end

  it 'verifies connectivity' do
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token) do |driver|
      expect { driver.verify_connectivity }.not_to raise_error
    end
  end

  it 'does not verify connectivity with bad auth token' do
    Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.none) do |driver|
      expect { driver.verify_connectivity }.to raise_error Neo4j::Driver::Exceptions::SecurityException
    end
  end

  it 'connects IPv6 uri' do
    Neo4j::Driver::GraphDatabase
      .driver("bolt://[::1]:#{port}", basic_auth_token) do |driver|
      driver.session do |session|
        result = session.run('RETURN 1')
        expect(result.single.first).to eq 1
      end
    end
  end
end
