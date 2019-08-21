# frozen_string_literal: true

RSpec.describe 'SessionSpec' do
  # it 'should know session is closed' do
  #   session = driver.session
  #   session.close
  #   expect(session.is_open?).to be false
  # end

  # it 'should handle nil config' do
  #   session = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'password'), nil)
  #   session.close
  #   expect(session.is_open?).to be false
  # end

  # it 'should handle nil AuthToken' do
  #   expect { Neo4j::Driver::GraphDatabase.driver(uri, nil) }
  #     .to raise_error
  # end

  it 'should execute read transaction in read session' do
    test_read_transaction(Neo4j::Driver::AccessMode::READ)
  end

  it 'should execute read transaction in write session' do
    test_read_transaction(Neo4j::Driver::AccessMode::WRITE)
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
end
