# frozen_string_literal: true

RSpec.describe 'SessionSpec' do
  # it 'knows session is closed' do
  #   session = driver.session
  #   session.close
  #   expect(session.is_open?).to be false
  # end

  # it 's nil config' do
  #   session = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'password'), nil)
  #   session.close
  #   expect(session.is_open?).to be false
  # end

  # it 'handles nil AuthToken' do
  #   expect { Neo4j::Driver::GraphDatabase.driver(uri, nil) }
  #     .to raise_error
  # end

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

  def test_read_transaction(mode)
    driver.session do |session|
      session.run( "CREATE (:Person {name: 'Tony Stark'})" ).consume;
      session.run( "CREATE (:Person {name: 'Steve Rogers'})" ).consume;
    end
    session = driver.session(mode)
    names = session.read_transaction do |tx|
      tx.run('MATCH (p:Person) RETURN p.name AS name').collect do |result|
        result['name']
      end
    end
    expect(names).to contain_exactly('Tony Stark', 'Steve Rogers')
  end

  def test_write_transaction(mode)
    session = driver.session(mode)
    session.write_transaction do |tx|
      node = tx.run("CREATE (s:Shield {material: 'Vibranium'}) RETURN s").next['s']
      expect(node.properties[:material]).to eq ('Vibranium')  
    end
    driver.session do |session|
      result = session.run('MATCH (s:Shield) RETURN s.material').next
      expect(result['s.material']).to eq('Vibranium')
    end
  end

  def test_tx_rollback_when_function_throws_exception(mode)
    session = driver.session(mode)
    expect {
      session.write_transaction do |tx|
        tx.run("CREATE (:Person {name: 'Thanos'})")
        tx.run( 'UNWIND range(0, 1) AS i RETURN 10/i')
        tx.success
      end
    }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Thanos'}) RETURN count(p)").next
      expect(result['count(p)']).to be_zero
    end
  end
end
