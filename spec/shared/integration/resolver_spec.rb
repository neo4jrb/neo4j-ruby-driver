# frozen_string_literal: true

# Ported from neo4j-java-driver ResolverIT.java —
# shouldFailInitialDiscoveryWhenConfiguredResolverThrows.
RSpec.describe 'Resolver' do
  it 'fails initial discovery when configured resolver throws' do
    addr_received = nil
    resolver = lambda { |addr|
      addr_received = addr
      raise 'Resolution failure!'
    }
    # Cross-flavour: JRuby surfaces the resolver's RuntimeError directly;
    # MRI wraps it in ServiceUnavailableException ("Failed to verify
    # connectivity: …Resolution failure!"). Match the underlying message
    # rather than a class with no common ancestor (cf. driver_close_spec).
    expect do
      Neo4j::Driver::GraphDatabase.driver(
        'neo4j://my.server.com:9001',
        basic_auth_token,
        encryption: false,
        resolver: resolver
      ) { |d| d.verify_connectivity }
    end.to raise_error(/Resolution failure!/)

    # The resolver was actually called with the configured address.
    expect(addr_received.to_s).to include('my.server.com').and include('9001')
  end
end
