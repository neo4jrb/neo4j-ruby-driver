# frozen_string_literal: true

RSpec.describe 'SessionSpec' do
  it 'knows session is closed' do
    session = driver.session
    session.close
    expect(session).not_to be_open
  end

  it 'handles nil config' do
    driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'password'))
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

  # it 'retries read transaction until success' do

  # end

  # it 'retries write transaction until success' do

  # end

  # it 'retries read transaction until failure' do

  # end

  # it 'retries write transaction until failure' do

  # end

  # it 'collects write transaction retry errors' do

  # end

  # it 'collects read transaction retry errors' do

  # end

  it 'commits read transaction without success' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.read_transaction { |tx| tx.run('RETURN 43').single[0] }
    session.close
    expect(answer).to eq(43)
    expect(session.last_bookmark).not_to be nil
  end

  it 'commits write transaction without success' do
    driver.session do |session|
      answer = session.write_transaction { |tx| tx.run("CREATE (:Person {name: 'Thor Odinson'}) RETURN 42").single[0] }
      expect(answer).to eq(42)
    end
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Thor Odinson'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(1)
  end

  it 'rolls back read transaction with failure' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.read_transaction do |tx|
      val = tx.run('RETURN 42').single[0]
      tx.failure
      val
    end
    session.close
    expect(answer).to eq(42)
    expect(session.last_bookmark).to be nil
  end

  it 'rolls back write transaction with failure' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      answer = session.write_transaction do |tx|
        tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
        tx.failure
        42
      end
      expect(answer).to eq(42)
    end
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end

  it 'rolls back read transaction when exception is thrown' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      expect do
        session.read_transaction do |tx|
          val = tx.run('RETURN 42').single[0]
          raise Neo4j::Driver::Exceptions::IllegalStateException if val == 42
          1
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
      expect(session.last_bookmark).to be nil
    end
  end

  it 'rolls back write transaction when exception is thrown' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      expect do
        session.write_transaction do |tx|
          tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
          raise Neo4j::Driver::Exceptions::IllegalStateException
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    end
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end

  it 'rolls back read transaction when marked both success and failure' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      answer = session.read_transaction do |tx|
        val = tx.run('RETURN 42').single[0]
        tx.success
        tx.failure
        val
      end
      expect(answer).to eq(42)
      expect(session.last_bookmark).to be nil
    end
  end

  it 'rolls back write transaction when marked both success and failure' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      answer = session.write_transaction do |tx|
        tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
        tx.success
        tx.failure
        42
      end
      expect(answer).to eq(42)
    end
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end

  it 'rolls back read transaction when marked success and throws exception' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      expect do
        session.read_transaction do |tx|
          tx.run('RETURN 42').single[0]
          tx.success
          raise Neo4j::Driver::Exceptions::IllegalStateException
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
      expect(session.last_bookmark).to be nil
    end
  end

  it 'rolls back write transaction when marked success and exception is thrown' do
    driver.session do |session|
      expect(session.last_bookmark).to be nil
      expect do
        session.write_transaction do |tx|
          tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
          tx.success
          raise Neo4j::Driver::Exceptions::IllegalStateException
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    end
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end

  # it 'transactionRunShouldFailOnDeadlocks' do

  # end

  # it 'writeTransactionFunctionShouldRetryDeadlocks' do

  # end

  # it 'shouldExecuteTransactionWorkInCallerThread' do

  # end

  it 'propagate failure when closed' do
    driver.session do |session|
      session.run('RETURN 10 / 0')
      expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end
  end

  it 'Propagate Pull All Failure When Closed' do
    driver.session do |session|
      session.run('UNWIND range(20000, 0, -1) AS x RETURN 10 / x')
      expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end
  end

  it 'is possible to consume result after session is closed' do
    driver.session do |session|
      ints = session.run('UNWIND range(1, 20000) AS x RETURN x').map { |record| record[0] }
      expect(ints.size).to eq(20_000)
    end
  end

  it 'Propagate Failure From Summary' do
    driver.session do |session|
      result = session.run('RETURN Wrong')
      expect { result.summary }.to raise_error Neo4j::Driver::Exceptions::ClientException
    end
  end

  it 'Throw From Close When Previous Error Not Consumed' do
    driver.session do |session|
      session.run('CREATE ()')
      session.run('CREATE ()')
      session.run('RETURN 10 / 0')
      expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end
  end

  it 'Throw From Run When Previous Error Not Consumed' do
    driver.session do |session|
      session.run('CREATE ()')
      session.run('CREATE ()')
      session.run('RETURN 10 / 0')
      expect { session.run('CREATE ()') }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end
  end

  it 'Close Cleanly When Run Error Consumed' do
    driver.session do |session|
      session.run('CREATE ()')
      expect do
        session.run('RETURN 10 / 0').consume
      end.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
      session.run('CREATE ()')
      session.close
      expect(session.open?).to eq(false)
    end
  end

  it 'Consume Previous Result Before Running New Query' do
    driver.session do |session|
      session.run('UNWIND range(1000, 0, -1) AS x RETURN 42 / x')
      expect { session.run('RETURN 1') }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end
  end

  # it 'shouldNotRetryOnConnectionAcquisitionTimeout' do
  # end

  it 'Allow Consuming Records After Failure In Session Close' do
    session = driver.session
    result = session.run('CYPHER runtime=interpreted UNWIND [2, 4, 8, 0] AS x RETURN 32 / x')
    expect(&session.method(:close)).to raise_error(Neo4j::Driver::Exceptions::ClientException) do |error|
      expect(error.code).to match(/ArithmeticError/)
    end
    expect(result).to have_next
    expect(result.next.first).to eq(16)
    expect(result).to have_next
    expect(result.next.first).to eq(8)
    expect(result).to have_next
    expect(result.next.first).to eq(4)
    expect(result).not_to have_next
  end

  it 'Allow Accessing Records After Summary' do
    driver.session do |session|
      record_count = 10_000
      query = 'UNWIND range(1, 10000) AS x RETURN x'
      result = session.run(query)
      summary = result.summary
      expect(summary.statement.text).to eq(query)
      expect(summary.statement_type).to eq(Neo4j::Driver::Summary::StatementType::READ_ONLY)
      records = result.to_a
      expect(records.size).to eq(record_count)
      records.each_with_index do |record, index|
        expect(record[0]).to eq(index + 1)
      end
    end
  end

  it 'Allow Accessing Records After Session Closed' do
    record_count = 11_333
    query = "UNWIND range(1, #{record_count}) AS x RETURN 'Result-' + x"
    result = driver.session do |session|
      session.run(query)
    end
    records = result.to_a
    expect(records.size).to eq(record_count)
    records.each_with_index do |record, index|
      expect(record[0]).to eq("Result-#{index + 1}")
    end
  end

  it 'Allow To Consume Records Slowly And Close Session' do
    driver.session do |session|
      result = session.run('UNWIND range(10000, 0, -1) AS x RETURN 10 / x')
      10.times do
        expect(result).to have_next
        expect(result.next).to be_present
        sleep(0.05)
      end
      expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException
    end
  end

  it 'Allow To Consume Records Slowly And Retrieve Summary' do
    driver.session do |session|
      result = session.run('UNWIND range(8000, 1, -1) AS x RETURN 42 / x')
      10.times do
        expect(result).to have_next
        expect(result.next).to be_present
        sleep(0.05)
      end
      expect(result.summary).to be_present
    end
  end

  # it 'shouldBeResponsiveToThreadInterruptWhenWaitingForResult' do

  # end

  # it 'shouldAllowLongRunningQueryWithConnectTimeout' do

  # end

  it 'Allow Returning Null From Transaction Function' do
    driver.session do |session|
      expect(session.write_transaction { nil }).to be_nil
      expect(session.read_transaction { nil }).to be_nil
    end
  end

  it 'Allow Iterating Over Empty Result' do
    driver.session do |session|
      result = session.run('UNWIND [] AS x RETURN x')
      expect(result).not_to have_next
      expect(&result.method(:next)).to raise_error Neo4j::Driver::Exceptions::NoSuchRecordException, 'No more records'
    end
  end

  it 'Allow Consuming Empty Result' do
    driver.session do |session|
      result = session.run('UNWIND [] AS x RETURN x')
      summary = result.consume
      expect(summary).to be_truthy
      expect(summary.statement_type).to eq(Neo4j::Driver::Summary::StatementType::READ_ONLY)
    end
  end

  it 'Allow List Empty Result' do
    driver.session do |session|
      result = session.run('UNWIND [] AS x RETURN x')
      expect(result).to be_none
    end
  end

  it 'Consume' do
    driver.session do |session|
      query = 'UNWIND [1, 2, 3, 4, 5] AS x RETURN x'
      result = session.run(query)
      summary = result.consume
      expect(summary.statement.text).to eq(query)
      expect(summary.statement_type).to eq(Neo4j::Driver::Summary::StatementType::READ_ONLY)
      expect(result).not_to have_next
      expect(result.to_a).to be_empty
    end
  end

  it 'Consume With Failure' do
    driver.session do |session|
      query = 'UNWIND [1, 2, 3, 4, 0] AS x RETURN 10 / x'
      result = session.run(query)
      expect { result.consume }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
      expect(result.summary.statement.text).to eq(query)
      expect(result).not_to have_next
      expect(result.to_a).to be_empty
    end
  end

  it 'Not Allow Starting Multiple Transactions' do
    driver.session do |session|
      tx = session.begin_transaction
      expect(tx).to be_truthy
      error_message = 'You cannot begin a transaction on a session with an open transaction; either run'\
                      ' from within the transaction or use a different session.'
      3.times do
        expect { session.begin_transaction }.to raise_error Neo4j::Driver::Exceptions::ClientException, error_message
      end
      tx.close
      expect(session.begin_transaction).to be_truthy
    end
  end

  it 'Close Open Transaction When Closed' do
    driver.session do |session|
      session.write_transaction do |tx|
        tx.run('CREATE (:Node {id: 123})')
        tx.run('CREATE (:Node {id: 456})')
        tx.success
      end
    end
    expect(count_nodes_with_id(123)).to eq(1)
    expect(count_nodes_with_id(456)).to eq(1)
  end

  it 'Rollback Open Transaction When Closed' do
    driver.session do |session|
      tx = session.begin_transaction
      tx.run('CREATE (:Node {id: 123})')
      tx.run('CREATE (:Node {id: 456})')
      tx.failure
    end
    expect(count_nodes_with_id(123)).to eq(0)
    expect(count_nodes_with_id(456)).to eq(0)
  end

  it 'Support Nested Queries' do
    driver.session do |session|
      session.run('UNWIND range(1, 100) AS x CREATE (:Property {id: x})').consume
      session.run('UNWIND range(1, 10) AS x CREATE (:Resource {id: x})').consume
      seen_properties = 0
      seen_resources = 0
      properties = session.run('MATCH (p:Property) RETURN p')
      while properties.has_next?
        expect(properties.next).to be_present
        seen_properties += 1
        resources = session.run('MATCH (r:Resource) RETURN r')
        while resources.has_next?
          expect(resources.next).to be_present
          seen_resources += 1
        end
      end
      expect(seen_properties).to eq(100)
      expect(seen_resources).to eq(1000)
    end
  end

  def count_nodes_with_id(id)
    driver.session do |session|
      session.run('MATCH (n {id: {id}}) RETURN count(n)', id: id).single[0]
    end
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
        expect(node.properties[:material]).to eq('Vibranium')
      end
    end
    driver.session do |session|
      result = session.run('MATCH (s:Shield) RETURN s.material').next
      expect(result['s.material']).to eq('Vibranium')
    end
  end

  def test_tx_rollback_when_function_throws_exception(mode)
    driver.session(mode) do |session|
      expect do
        session.write_transaction do |tx|
          tx.run("CREATE (:Person {name: 'Thanos'})")
          tx.run('UNWIND range(0, 1) AS i RETURN 10/i')
          tx.success
        end
      end.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Thanos'}) RETURN count(p)").next
      expect(result['count(p)']).to be_zero
    end
  end
end
