# frozen_string_literal: true

RSpec.describe Neo4j::Driver::GraphDatabase do
  def simple_query(driver)
    driver.session do |session|
      session.read_transaction { |tx| tx.run('RETURN 1').single.first }
    end
  end

  let(:url) { URI::Generic.build(scheme: scheme, host: URI(uri).host, port: port).to_s }
  describe '.driver' do
    subject do
      Neo4j::Driver::GraphDatabase.driver(url, basic_auth_token, encryption: false, &method(:simple_query))
    end

    context 'when neo4j' do
      let(:scheme) { 'neo4j' }
      it { is_expected.to eq 1 }
    end

    context 'when bolt' do
      let(:scheme) { 'bolt' }
      it { is_expected.to eq 1 }
    end

    context 'when bolt+routing' do
      let(:scheme) { 'bolt+routing' }
      it { is_expected.to eq 1 }
    end
  end

  describe '.routing_driver' do
    let(:routing_uris) { [url] }
    subject do
      Neo4j::Driver::GraphDatabase.routing_driver(routing_uris, basic_auth_token, encryption: false,
                                                  &method(:simple_query))
    end

    context 'when neo4j' do
      let(:scheme) { 'neo4j' }
      it { is_expected.to eq 1 }
    end

    context 'when bolt' do
      let(:scheme) { 'bolt' }
      it 'is not routing scheme' do
        expect { subject }
          .to raise_error ArgumentError,
                          "Illegal URI scheme, expected URI scheme 'bolt' to be among [bolt+routing, neo4j]"
      end
    end

    context 'when bolt+routing' do
      let(:scheme) { 'bolt+routing' }
      it { is_expected.to eq 1 }
    end
  end
end