# frozen_string_literal: true

RSpec.describe 'AsyncSession' do
  context 'driver' do
    let(:driver2) { Neo4j::Driver::GraphDatabase.driver(uri, auth_tokens, config) }
    let(:auth_tokens) { Neo4j::Driver::AuthTokens.basic('neo4j', 'pass') }
    let(:config) { {} }

    it 'close_async' do
      driver2.close_async.wait!
    end
  end

  let(:session) { driver.asyncSession }

  after { session.closeAsync }

  it 'runs query with empty result' do
    cursor = session.run_async("CREATE (:Person)").value!
    expect(cursor).to be_present
    expect(cursor.next_async.value!).to be_nil
  end

  it 'ruby way: runs query with empty result' do
    expect(session.run_async("CREATE (:Person)").then(&:next_async).flat.value!).to be_nil
  end

  it 'runs query with single result' do
    cursor = session.run_async("CREATE (p:Person {name: 'Nick Fury'}) RETURN p").value!
    record = cursor.next_async.value!
    expect(record).to be_present
    node = record[0]
    expect(node.labels).to eq [:Person]
    expect(node["name"]).to eq 'Nick Fury'
    expect(cursor.next_async.value!).to be_nil
  end
end
