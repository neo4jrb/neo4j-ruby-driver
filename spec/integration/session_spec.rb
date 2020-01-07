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

  class RaisingWork
    attr_reader :invoked

    def initialize(query, failures)
      @query = query
      @failures = failures
      @invoked = 0
    end

    def execute(tx)
      result = tx.run(@query)
      raise Neo4j::Driver::Exceptions::ServiceUnavailableException if (@invoked += 1) <= @failures
      tx.success
      result.single
    end

    def to_proc
      method(:execute)
    end
  end

  it 'retries read transaction until success' do
    driver.session do |session|
      session.run("CREATE (:Person {name: 'Bruce Banner'})")
    end

    work = RaisingWork.new('MATCH (n) RETURN n.name', 2)

    driver.session do |session|
      record = session.read_transaction(&work.to_proc)
      expect(record[0]).to eq 'Bruce Banner'
    end

    expect(work.invoked).to eq 3
  end

  it 'retries write transaction until success' do
    work = RaisingWork.new("CREATE (p:Person {name: 'Hulk'}) RETURN p", 2)
    driver.session do |session|
      record = session.write_transaction(&work.to_proc)
      expect(record[0][:name]).to eq 'Hulk'
    end

    driver.session do |session|
      record = session.run("MATCH (p: Person {name: 'Hulk'}) RETURN count(p)").single
      expect(record[0]).to eq 1
    end

    expect(work.invoked).to eq 3
  end

  it 'retries read transaction until failure' do
    work = RaisingWork.new('MATCH (n) RETURN n.name', 3)
    driver.session do |session|
      expect { session.read_transaction(&work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException
    end

    expect(work.invoked).to eq 3
  end

  it 'retries write transaction until failure' do
    work = RaisingWork.new("CREATE (:Person {name: 'Ronan'})", 3)
    driver.session do |session|
      expect { session.read_transaction(&work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException
    end

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Ronan'}) RETURN count(p)")
      expect(result.single[0]).to eq 0
    end
    expect(work.invoked).to eq 3
  end

  it 'collects write transaction retry errors' do
    work = RaisingWork.new("CREATE (:Person {name: 'Ronan'})", 1000)
    suppressed_errors = nil
    driver.session do |session|
      expect { session.write_transaction(&work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException do |e|
        expect(e.suppressed).to be_present
        suppressed_errors = e.suppressed.size
      end
    end

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Ronan'}) RETURN count(p)")
      expect(result.single[0]).to be_zero
    end

    expect(work.invoked).to eq suppressed_errors + 1
  end

  it 'collects read transaction retry errors' do
    work = RaisingWork.new('MATCH (n) RETURN n.name', 1000)
    suppressed_errors = nil
    driver.session do |session|
      expect { session.read_transaction(&work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException do |e|
        expect(e.suppressed).to be_present
        suppressed_errors = e.suppressed.size
      end
    end

    expect(work.invoked).to eq suppressed_errors + 1
  end

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

  # This multi threaded scenario deadlocks outside of neo4j on MRI due to Global Interpreter Lock und so it never comes
  # to the neo4j transaction deadlock which would be discovered and resolved by the neo4j server
  it 'transaction run fails on deadlocks', concurrency: true do
    node_id1 = 42
    node_id2 = 4242
    new_node_id1 = 1
    new_node_id2 = 2

    create_node_with_id(node_id1)
    create_node_with_id(node_id2)

    latch1 = Concurrent::CountDownLatch.new(1)
    latch2 = Concurrent::CountDownLatch.new(1)

    result1 = Concurrent::Promises.future do
      driver.session do |session|
        tx = session.begin_transaction

        # lock first node
        update_node_id(tx, node_id1, new_node_id1).consume

        latch1.wait
        latch2.count_down

        # lock second node
        update_node_id(tx, node_id2, new_node_id1).consume

        tx.success
      end
      nil
    end

    result2 = Concurrent::Promises.future do
      driver.session do |session|
        tx = session.begin_transaction

        # lock second node
        update_node_id(tx, node_id2, new_node_id2).consume

        latch1.count_down
        latch2.wait

        # lock first node
        update_node_id(tx, node_id1, new_node_id2).consume

        tx.success
      end
      nil
    end

    first_result_failed = assert_one_of_two_futures_fail_with_deadlock(result1, result2)
    if first_result_failed
      expect(count_nodes_with_id(new_node_id1)).to be_zero
      expect(count_nodes_with_id(new_node_id2)).to eq 2
    else
      expect(count_nodes_with_id(new_node_id1)).to eq 2
      expect(count_nodes_with_id(new_node_id2)).to be_zero
    end
  end

  it 'write transaction function retries deadlocks', concurrency: true do
    node_id1 = 42
    node_id2 = 4242
    node_id3 = 424242
    new_node_id1 = 1
    new_node_id2 = 2

    create_node_with_id(node_id1)
    create_node_with_id(node_id2)

    latch1 = Concurrent::CountDownLatch.new(1)
    latch2 = Concurrent::CountDownLatch.new(1)

    result1 = Concurrent::Promises.future do
      driver.session do |session|
        tx = session.begin_transaction

        # lock first node
        update_node_id(tx, node_id1, new_node_id1).consume

        latch1.wait
        latch2.count_down

        # lock second node
        update_node_id(tx, node_id2, new_node_id1).consume

        tx.success
      end
      nil
    end

    result2 = Concurrent::Promises.future do
      driver.session do |session|
        session.write_transaction do |tx|
          # lock second node
          update_node_id(tx, node_id2, new_node_id2).consume

          latch1.count_down
          latch2.wait

          # lock first node
          update_node_id(tx, node_id1, new_node_id2).consume

          create_node_with_id(node_id3)

          nil
        end
      end
      nil
    end

    first_result_failed = false
    begin
      # first future may:
      # 1) succeed, when it's tx was able to grab both locks and tx in other future was
      #    terminated because of a deadlock
      # 2) fail, when it's tx was terminated because of a deadlock
      expect(result1.value!(20)).to be_nil
    rescue Neo4j::Driver::Exceptions::TransientException
      first_result_failed = true
    end

    # second future can't fail because deadlocks are retried
    expect(result2.value!(20)).to be_nil

    if first_result_failed
      # tx with retries was successful and updated ids
      expect(count_nodes_with_id(new_node_id1)).to be_zero
      expect(count_nodes_with_id(new_node_id2)).to eq 2
    else
      # tx without retries was successful and updated ids
      # tx with retries did not manage to find nodes because their ids were updated
      expect(count_nodes_with_id(new_node_id1)).to eq 2
      expect(count_nodes_with_id(new_node_id2)).to be_zero
    end
    # tx with retries was successful and created an additional node
    expect(count_nodes_with_id(node_id3)).to eq 1
  end

  it 'executes transaction work in caller thread' do
    max_failures = 3
    caller_thread = Thread.current
    failures = 0
    result = driver.session do |session|
      session.read_transaction do
        expect(Thread.current).to eq caller_thread
        raise Neo4j::Driver::Exceptions::ServiceUnavailableException, 'Oh no' if (failures += 1) < max_failures
        'Hello'
      end
    end
    expect(result).to eq 'Hello'
  end

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

  it 'does not retry on connection acquisition timeout' do
    max_pool_size = 3
    config = {
      max_connection_pool_size: max_pool_size,
      connection_acquisition_timeout: 0,
      max_transaction_retry_time: 42.days, # retry for a really long time
    }
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token, config) do |driver|
      max_pool_size.times { driver.session.begin_transaction }

      invocations = Concurrent::AtomicFixnum.new
      expect { driver.session.write_transaction { invocations.increment } }
        .to raise_error Neo4j::Driver::Exceptions::ClientException,
                        'Unable to acquire connection from the pool within configured maximum time of 0ms'
      # work should never be invoked
      expect(invocations.value).to be_zero
    end
  end

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

  #it 'is responsive to thread interrupt when waiting for result' do
  #  driver.session do |session1|
  #    session2 = driver.session
  #
  #    session1.run("CREATE (:Person {name: 'Beta Ray Bill'})").consume
  #
  #    tx = session1.begin_transaction
  #    tx.run("MATCH (n:Person {name: 'Beta Ray Bill'}) SET n.hammer = 'Mjolnir'").consume
  #
  #    # now 'Beta Ray Bill' node is locked
  #
  #    # setup other thread to interrupt current thread when it blocks
  #    thread = Thread.current
  #    Concurrent::Promises.future do
  #      # spin until given thread moves to WAITING state
  #      begin
  #        sleep(0.5)
  #      end until thread.status == 'sleep'
  #      thread.wakeup
  #    end
  #
  #    expect { session2.run("MATCH (n:Person {name: 'Beta Ray Bill'}) SET n.hammer = 'Stormbreaker'").consume }
  #      .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException do |error|
  #      error.message =~ /Connection to the database terminated/
  #      error.message =~ /Thread interrupted/
  #    end
  #  ensure
  #    session2&.close
  #  end
  #end

  it 'allows long running query with connect timeout', concurrency: true do
    session1 = driver.session
    session2 = driver.session

    session1.run("CREATE (:Avenger {name: 'Hulk'})").consume

    tx = session1.begin_transaction
    tx.run("MATCH (a:Avenger {name: 'Hulk'}) SET a.power = 100 RETURN a").consume

    # Hulk node is now locked

    latch = Concurrent::CountDownLatch.new(1)
    update_future = Concurrent::Promises.future do
      latch.count_down
      session2.run("MATCH (a:Avenger {name: 'Hulk'}) SET a.weight = 1000 RETURN a.power").single.first
    end

    latch.wait
    # sleep more than connection timeout
    sleep(3 + 1)
    # verify that query is still executing and has not failed because of the read timeout
    expect(update_future).not_to be_resolved

    tx.success
    tx.close

    hulk_power = update_future.value!(10)
    expect(hulk_power).to eq 100
  ensure
    session1&.close
    session2&.close
  end

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

  def create_node_with_id(id)
    driver.session do |session|
      session.run('CREATE (n {id: {id}})', id: id)
    end
  end

  def update_node_id(statement_runner, current_id, new_id)
    statement_runner.run('MATCH (n {id: {current_id}}) SET n.id = {new_id}', current_id: current_id, new_id: new_id)
  end

  def assert_one_of_two_futures_fail_with_deadlock(future1, future2)
    first_failed = false
    begin
      expect(future1.value!(20)).to be_nil
    rescue Exception => e
      assert_deadlock_detected_error(e)
      first_failed = true
    end

    begin
      expect(future2.value!(20)).to be_nil
    rescue Exception => e
      expect(first_failed).to be false
      assert_deadlock_detected_error(e)
    end

    first_failed
  end

  def assert_deadlock_detected_error(e)
    expect(e).to be_a Neo4j::Driver::Exceptions::TransientException
    expect(e.code).to eq 'Neo.TransientError.Transaction.DeadlockDetected'
  end
end
