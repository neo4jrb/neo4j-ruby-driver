# frozen_string_literal: true

require_relative 'puppygraph_helper'

RSpec.describe 'PuppyGraph 0.118 Bolt integration' do
  let(:uri)  { ENV.fetch('PUPPYGRAPH_BOLT_URL', 'bolt://localhost:7687') }
  let(:user) { ENV.fetch('PUPPYGRAPH_USERNAME', 'puppygraph') }
  let(:pass) { ENV.fetch('PUPPYGRAPH_PASSWORD', 'puppygraph123') }

  let(:driver) do
    Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, pass))
  end

  after { driver&.close }

  it 'connects and returns a literal' do
    driver.session do |session|
      result = session.run('RETURN 1 AS n')
      expect(result.single['n']).to eq(1)
    end
  end

  it 'returns scalar string and arithmetic results' do
    driver.session do |session|
      result = session.run('RETURN "hello" AS s, 1 + 2 AS n')
      row = result.single
      expect(row['s']).to eq('hello')
      expect(row['n']).to eq(3)
    end
  end

  it 'iterates a multi-row result' do
    driver.session do |session|
      result = session.run('UNWIND range(1, 5) AS n RETURN n')
      expect(result.map { |r| r['n'] }).to eq([1, 2, 3, 4, 5])
    end
  end

  it 'queries an Identity vertex if any exist (does not assert on data)' do
    driver.session do |session|
      result = session.run('MATCH (i:Identity) RETURN i LIMIT 1')
      result.to_a # exhaust without raising
      expect(true).to be true
    end
  end
end
