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
      Neo4j::Driver::GraphDatabase.driver(url, basic_auth_token, &method(:simple_query))
    end

    context 'when bolt' do
      let(:scheme) { 'bolt' }
      it { is_expected.to eq 1 }
    end

    context 'when neo4j', version: '>=4' do
      let(:scheme) { 'neo4j' }
      it { is_expected.to eq 1 }
    end
  end
end
