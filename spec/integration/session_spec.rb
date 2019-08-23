# frozen_string_literal: true

RSpec.describe 'SessionSpec' do
  it 'knows session is closed' do
    session = driver.session
    session.close
    expect(session).not_to be_open
  end

  it 'handles nil config' do
    driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'password'), nil)
    session = driver.session
    session.close
    expect(session).not_to be_open
    driver.close
  end

  it 'handles nil AuthToken' do
    expect { Neo4j::Driver::GraphDatabase.driver(uri, nil) {} }
      .to raise_error Neo4j::Driver::Exceptions::AuthenticationException
  end

  it 'executes read transaction in read session' do
    test_read_transaction(Neo4j::Driver::AccessMode::READ)
  end

  it 'executes read transaction in write session' do
    test_read_transaction(Neo4j::Driver::AccessMode::WRITE)
  end

  it 'executes write transaction in read session' do
    test_write_transaction(Neo4j::Driver::AccessMode::READ)
  end

  it 'executes write transaction in write session' do
    test_write_transaction(Neo4j::Driver::AccessMode::WRITE)
  end

  it 'rolls back write transaction in read session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::READ)
  end

  it 'rolls back write transaction in write session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::WRITE)
  end

  it 'retries read transaction until success' do

  end

  it 'retries read transaction until failure' do

  end

  it 'retries write transaction until failure' do

  end

  def test_read_transaction(mode)
    driver.session do |session|
      session.run("CREATE (:Person {name: 'Tony Stark'})").consume
      session.run("CREATE (:Person {name: 'Steve Rogers'})").consume
    end
    driver.session(mode) do |session|
      names = session.read_transaction do |tx|
        tx.run('MATCH (p:Person) RETURN p.name AS name').collect do |result|
          result['name']
        end
      end
      expect(names).to contain_exactly('Tony Stark', 'Steve Rogers')
    end
  end

  def test_write_transaction(mode)
    driver.session(mode) do |session|
      session.write_transaction do |tx|
        node = tx.run("CREATE (s:Shield {material: 'Vibranium'}) RETURN s").next['s']
        expect(node.properties[:material]).to eq ('Vibranium')
      end
    end
    driver.session do |session|
      result = session.run('MATCH (s:Shield) RETURN s.material').next
      expect(result['s.material']).to eq('Vibranium')
    end
  end

  def test_tx_rollback_when_function_throws_exception(mode)
    driver.session(mode) do |session|
      expect {
        session.write_transaction do |tx|
          tx.run("CREATE (:Person {name: 'Thanos'})")
          tx.run('UNWIND range(0, 1) AS i RETURN 10/i')
          tx.success
        end
      }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Thanos'}) RETURN count(p)").next
      expect(result['count(p)']).to be_zero
    end
  end
end
