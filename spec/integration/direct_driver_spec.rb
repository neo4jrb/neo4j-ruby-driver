# frozen_string_literal: true

RSpec.describe 'DirectDriverSpec' do
  it 'allows IPv6 address' do
    skip 'IPv6 not supported on travis'
    Neo4j::Driver::GraphDatabase.driver("bolt://[::1]:#{port}", basic_auth_token) do |driver|
      # verifying address is implementation dependent and goes beyond integration testing
    end
  end

  it 'rejects invalid address' do
    expect { Neo4j::Driver::GraphDatabase.driver('*', basic_auth_token) }
      .to raise_error ArgumentError, 'Invalid address format `*`'
  end

  it 'registers single server' do
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token) do |driver|
      # verifying address is implementation dependent and goes beyond integration testing
    end
  end

  it 'connects IPv6 uri' do
    skip 'IPv6 not supported on travis'
    Neo4j::Driver::GraphDatabase.driver("bolt://[::1]:#{port}", basic_auth_token) do |driver|
      driver.session do |session|
        result = session.run('RETURN 1')
        expect(result.single.first).to eq 1
      end
    end
  end
end
