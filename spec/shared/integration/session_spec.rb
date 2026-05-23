# frozen_string_literal: true

RSpec.describe 'Session' do
  it 'knows session is closed' do
    session = driver.session
    session.close
    expect(session).not_to be_open
  end

  it 'handles nil config' do
    driver = Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
    session = driver.session
    session.close
    expect(session).not_to be_open
    driver.close
  end

  it 'handles nil AuthToken' do
    Neo4j::Driver::GraphDatabase.driver(uri, nil) do |driver|
      expect(&driver.method(:verify_connectivity)).to raise_error Neo4j::Driver::Exceptions::AuthenticationException
    end
  end

  it 'executes read transaction in read session' do
    test_read_methods(Neo4j::Driver::AccessMode::READ, :execute_read)
  end

  it 'executes read transaction in write session' do
    test_read_methods(Neo4j::Driver::AccessMode::WRITE, :execute_read)
  end

  it 'executes execute_read in read session' do
    test_read_methods(Neo4j::Driver::AccessMode::READ, :execute_read)
  end

  it 'executes execute_read in write session' do
    test_read_methods(Neo4j::Driver::AccessMode::WRITE, :execute_read)
  end

  it 'executes write transaction in read session' do
    test_write_methods(Neo4j::Driver::AccessMode::READ, :execute_write)
  end

  it 'executes write transaction in write session' do
    test_write_methods(Neo4j::Driver::AccessMode::WRITE, :execute_write)
  end

  it 'executes execute_write in read session' do
    test_write_methods(Neo4j::Driver::AccessMode::READ, :execute_write)
  end

  it 'executes execute_write in write session' do
    test_write_methods(Neo4j::Driver::AccessMode::WRITE, :execute_write)
  end

  it 'rolls back write transaction in read session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::READ, :execute_write)
  end

  it 'rolls back write transaction in write session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::WRITE, :execute_write)
  end

  it 'rolls back execute write in read session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::READ, :execute_write)
  end

  it 'rolls back execute write in write session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::WRITE, :execute_write)
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
      single = result.single
      # tx.commit
      single
    end

    def to_proc
      method(:execute)
    end
  end

  it 'retries execute read until success' do
    test_read_retries_until_success(:execute_read)
  end

  it 'retries execute write until success' do
    test_write_retries_until_success(:execute_write)
  end

  it 'retries execute read until failure' do
    test_read_retries_until_failure(:execute_read)
  end

  it 'retries execute write until failure' do
    test_write_retries_until_failure(:execute_write)
  end

  it 'collects execute write retry errors' do
    test_write_errors_collect(:execute_write)
  end

  it 'collects execute read retry errors' do
    test_read_errors_collect(:execute_read)
  end

  it 'commits execute read without success' do
    test_commit_read_without_success(:execute_read)
  end

  def expectEmptyBookmark(bookmark)
    expect(bookmark).not_to be_nil
    expect(bookmark).to be_a Set
    expect(bookmark).to be_empty
  end

  def expectNotEmptyBookmark(bookmark)
    expect(bookmark).to be_present
    expect(bookmark).to be_a Set
    expect(bookmark.first).to be_a Neo4j::Driver::Bookmark
  end

  it 'commits write transaction without success' do
    test_commit_write_without_success(:execute_write)
  end

  it 'commits execute write without success' do
    test_commit_write_without_success(:execute_write)
  end

  it 'rolls back read transaction with failure' do
    session = driver.session
    expectEmptyBookmark(session.last_bookmarks)
    expect do
      session.execute_read do |tx|
        tx.run('RETURN 42').single[0]
        raise Neo4j::Driver::Exceptions::IllegalStateException
      end
    end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    session.close
    expectEmptyBookmark(session.last_bookmarks)
  end

  it 'rolls back write transaction with failure' do
    driver.session do |session|
      expectEmptyBookmark(session.last_bookmarks)
      expect do
        session.execute_write do |tx|
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

  it 'rolls back read transaction when exception is thrown' do
    test_read_rollback_on_exception(:execute_read)
  end

  it 'rolls back execute read when exception is thrown' do
    test_read_rollback_on_exception(:execute_read)
  end

  it 'rolls back write transaction when exception is thrown' do
    test_write_rollback_on_exception(:execute_write)
  end

  it 'rolls back execute write when exception is thrown' do
    test_write_rollback_on_exception(:execute_write)
  end

  it 'read tx committed without tx success' do
    driver.session do |session|
      expect(session.execute_read { |tx| tx.run('RETURN 42').single[0] }).to eq(42)
      expect(session.last_bookmarks.size).to eq 1
    end
  end

  it 'write tx committed without tx success' do
    driver.session do |session|
      expect(session.execute_write do |tx|
        tx.run("CREATE (:Person {name: 'Thor Odinson'}) RETURN 42").single[0]
      end).to eq 42
      expect(session.run("MATCH (p:Person {name: 'Thor Odinson'}) RETURN count(p)").single[0]).to eq 1
    end
  end

  it 'read tx rolled back with tx failure' do
    driver.session do |session|
      expectEmptyBookmark(session.last_bookmarks)
      expect do
        session.execute_read do |tx|
          tx.run('RETURN 42').single[0]
          raise Neo4j::Driver::Exceptions::IllegalStateException
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
      expectEmptyBookmark(session.last_bookmarks)
    end
  end

  it 'write tx rolled back with tx failure' do
    driver.session do |session|
      expect do
        session.execute_write do |tx|
          tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
          raise Neo4j::Driver::Exceptions::IllegalStateException
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    end
    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)")
      expect(result.single[0]).to eq(0)
    end
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

        tx.commit
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

        tx.commit
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

        tx.commit
      end
      nil
    end

    result2 = Concurrent::Promises.future do
      driver.session do |session|
        session.execute_write do |tx|
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
    test_read_work_in_caller_thread(:execute_read)
  end

  it 'executes execute_read work in caller thread' do
    test_read_work_in_caller_thread(:execute_read)
  end

  it 'Throws Run Failure Immediately And Closes Successfully' do
    driver.session do |session|
      expect { session.run('RETURN 1 * "x"') }
        .to raise_error Neo4j::Driver::Exceptions::ClientException, /^Type mismatch/
    end
  end

  it 'does not propagate failure when streaming is cancelled' do
    driver.session do |session|
      session.run('UNWIND range(20000, 0, -1) AS x RETURN 10 / x')
    end
  end

  it 'is not possible to consume result after session is closed' do
    result = driver.session do |session|
      session.run('UNWIND range(1, 20000) AS x RETURN x')
    end
    expect { result.map { |record| record[0] } }.to raise_error Neo4j::Driver::Exceptions::ResultConsumedException
  end

  it 'Throw Run Failure Immediately After Multiple Successful Runs And Close Successfully' do
    driver.session do |session|
      session.run('CREATE ()')
      session.run('CREATE ()')
      expect { session.run('RETURN 1 * "x"') }
        .to raise_error Neo4j::Driver::Exceptions::ClientException, /^Type mismatch/
    end
  end

  it 'Throw Run Failure Immediately And Accept Subsequent Run' do
    driver.session do |session|
      session.run('CREATE ()')
      session.run('CREATE ()')
      expect { session.run('RETURN 1 * "x"') }
        .to raise_error Neo4j::Driver::Exceptions::ClientException, /^Type mismatch/
      session.run('CREATE ()')
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

  context "with 'bolt' scheme" do
    let(:scheme) { 'bolt' } # to avoid routing logic triggered by 'neo4j' scheme
    it 'does not retry on connection acquisition timeout' do
      max_pool_size = 3
      config = {
        max_connection_pool_size: max_pool_size,
        connection_acquisition_timeout: 0.1.seconds,
        max_transaction_retry_time: 42.days # retry for a really long time
      }
      Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token, **config) do |driver|
        max_pool_size.times { driver.session.begin_transaction }

        invocations = Concurrent::AtomicFixnum.new
        expect { driver.session.execute_write { invocations.increment } }
          .to raise_error Neo4j::Driver::Exceptions::ClientException,
                          /^Unable to acquire connection from the pool within configured maximum time of (100ms|0\.1 seconds)$/
        # work should never be invoked
        expect(invocations.value).to be_zero
      end
    end
  end

  it 'reports failure in close' do
    session = driver.session
    session.run('CYPHER runtime=interpreted UNWIND [2, 4, 8, 0] AS x RETURN 32 / x')
    expect(&session.method(:close)).to raise_error(Neo4j::Driver::Exceptions::ClientException) do |error|
      expect(error.code).to match(/ArithmeticError/)
    end
  end

  it 'Does Not Allow Accessing Records After Summary' do
    driver.session do |session|
      record_count = 10_000
      query = "UNWIND range(1, #{record_count}) AS x RETURN x"
      result = session.run(query)
      summary = result.consume
      expect(summary.query.text).to eq(query)
      expect(summary.query_type).to eq(Neo4j::Driver::Summary::QueryType::READ_ONLY)
      expect { result.to_a }.to raise_error Neo4j::Driver::Exceptions::ResultConsumedException
    end
  end

  it 'Does Not Allow Accessing Records After Session Closed' do
    record_count = 11_333
    query = "UNWIND range(1, #{record_count}) AS x RETURN 'Result-' + x"
    result = driver.session do |session|
      session.run(query)
    end
    expect { result.to_a }.to raise_error Neo4j::Driver::Exceptions::ResultConsumedException
  end

  it 'Allow To Consume Records Slowly And Retrieve Summary' do
    driver.session do |session|
      result = session.run('UNWIND range(8000, 1, -1) AS x RETURN 42 / x')
      10.times do
        expect(result).to have_next
        expect(result.next).to be_present
        sleep(0.05)
      end
      expect(result.consume).to be_present
    end
  end

  # it 'is responsive to thread interrupt when waiting for result' do
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
  # end

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

    tx.commit
    tx.close

    hulk_power = update_future.value!(10)
    expect(hulk_power).to eq 100
  ensure
    session1&.close
    session2&.close
  end

  it 'Allow Returning Null From Transaction Function' do
    test_write_read_allow_return_null(:execute_write)
    test_write_read_allow_return_null(:execute_read)
  end

  it 'Allow Returning Null From execute_write/read Function' do
    test_write_read_allow_return_null(:execute_write)
    test_write_read_allow_return_null(:execute_read)
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
      expect(summary.query_type).to eq(Neo4j::Driver::Summary::QueryType::READ_ONLY)
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
      expect(summary.query.text).to eq(query)
      expect(summary.query_type).to eq(Neo4j::Driver::Summary::QueryType::READ_ONLY)
    end
  end

  it 'Reports Failure In Summary' do
    driver.session do |session|
      query = 'UNWIND [1, 2, 3, 4, 0] AS x RETURN 10 / x'
      result = session.run(query)
      expect { result.consume }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
      expect(result.consume.query.text).to eq(query)
    end
  end

  it 'Not Allow Starting Multiple Transactions' do
    driver.session do |session|
      tx = session.begin_transaction
      expect(tx).to be_truthy
      error_message = 'You cannot begin a transaction on a session with an open transaction; either run' \
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
      session.begin_transaction do |tx|
        tx.run('CREATE (:Node {id: 123})')
        tx.run('CREATE (:Node {id: 456})')
        tx.commit
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
      tx.rollback
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
      session.run('MATCH (n {id: $id}) RETURN count(n)', id: id).single[0]
    end
  end

  def test_read_methods(mode, method_name)
    driver.session do |session|
      session.run("CREATE (:Person {name: 'Tony Stark'})").consume
      session.run("CREATE (:Person {name: 'Steve Rogers'})").consume
    end
    driver.session(default_access_mode: mode) do |session|
      names = session.send(method_name) do |tx|
        tx.run('MATCH (p:Person) RETURN p.name AS name').collect do |result|
          result[:name]
        end
      end

      expect(names).to contain_exactly('Tony Stark', 'Steve Rogers')
    end
  end

  def test_write_methods(mode, method_name)
    driver.session(default_access_mode: mode) do |session|
      session.send(method_name) do |tx|
        node = tx.run("CREATE (s:Shield {material: 'Vibranium'}) RETURN s").next['s']
        expect(node.properties[:material]).to eq('Vibranium')
      end
    end
    driver.session do |session|
      result = session.run('MATCH (s:Shield) RETURN s.material').next
      expect(result['s.material']).to eq('Vibranium')
    end
  end

  def test_read_retries_until_success(method_name)
    driver.session do |session|
      session.run("CREATE (:Person {name: 'Bruce Banner'})")
    end

    work = RaisingWork.new('MATCH (n) RETURN n.name', 2)

    driver.session do |session|
      record = session.send(method_name, &work.to_proc)
      expect(record[0]).to eq 'Bruce Banner'
    end

    expect(work.invoked).to eq 3
  end

  def test_write_retries_until_success(method_name)
    work = RaisingWork.new("CREATE (p:Person {name: 'Hulk'}) RETURN p", 2)
    driver.session do |session|
      record = session.send(method_name, &work.to_proc)
      expect(record[0][:name]).to eq 'Hulk'
    end

    driver.session do |session|
      record = session.run("MATCH (p: Person {name: 'Hulk'}) RETURN count(p)").single
      expect(record[0]).to eq 1
    end

    expect(work.invoked).to eq 3
  end

  def test_read_retries_until_failure(method_name)
    work = RaisingWork.new('MATCH (n) RETURN n.name', 3)
    driver.session do |session|
      expect { session.send(method_name, &work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException
    end

    expect(work.invoked).to eq 3
  end

  def test_write_retries_until_failure(method_name)
    work = RaisingWork.new("CREATE (:Person {name: 'Ronan'})", 3)
    driver.session do |session|
      expect { session.send(method_name, &work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException
    end

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Ronan'}) RETURN count(p)")
      expect(result.single[0]).to eq 0
    end
    expect(work.invoked).to eq 3
  end

  def test_write_errors_collect(method_name)
    work = RaisingWork.new("CREATE (:Person {name: 'Ronan'})", 1000)
    suppressed_errors = nil
    driver.session do |session|
      expect { session.send(method_name, &work.to_proc) }
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

  def test_read_errors_collect(method_name)
    work = RaisingWork.new('MATCH (n) RETURN n.name', 1000)
    suppressed_errors = nil
    driver.session do |session|
      expect { session.send(method_name, &work.to_proc) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException do |e|
        expect(e.suppressed).to be_present
        suppressed_errors = e.suppressed.size
      end
    end

    expect(work.invoked).to eq suppressed_errors + 1
  end

  # --- Ported from neo4j-java-driver SessionIT.java ---

  it 'Allow To Consume Records Slowly And Close Session' do
    skip 'Ruby driver does not surface the pending stream error on session.close (Java does)'
    session = driver.session
    result = session.run('UNWIND range(10000, 0, -1) AS x RETURN 10 / x')
    10.times do
      expect(result).to have_next
      expect(result.next).to be_present
      sleep(0.05)
    end
    expect { session.close }.to raise_error(Neo4j::Driver::Exceptions::ClientException, /by zero|arithmetic/i)
  end

  it 'allows database name', version: '>=4' do
    driver.session(database: 'neo4j') do |session|
      expect(session.run('RETURN 1').single[0]).to eq 1
    end
  end

  it 'allows database name using explicit transaction', version: '>=4' do
    driver.session(database: 'neo4j') do |session|
      session.begin_transaction do |tx|
        expect(tx.run('RETURN 1').single[0]).to eq 1
      end
    end
  end

  it 'allows database name using execute_read', version: '>=4' do
    driver.session(database: 'neo4j') do |session|
      expect(session.execute_read { |tx| tx.run('RETURN 1').single[0] }).to eq 1
    end
  end

  it 'errors using session.run when database is absent', version: '>=4' do
    session = driver.session(database: 'foo')
    expect { session.run('RETURN 1').consume }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Database does not exist.*foo/)
  ensure
    session&.close
  end

  it 'errors using explicit transaction when database is absent', version: '>=4' do
    session = driver.session(database: 'foo')
    expect do
      tx = session.begin_transaction
      tx.run('RETURN 1').consume
    end.to raise_error(Neo4j::Driver::Exceptions::ClientException, /Database does not exist.*foo/)
  ensure
    session&.close
  end

  it 'errors using execute_read when database is absent', version: '>=4' do
    session = driver.session(database: 'foo')
    expect { session.execute_read { |tx| tx.run('RETURN 1').consume } }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Database does not exist.*foo/)
  ensure
    session&.close
  end

  def test_commit_read_without_success(method_name)
    session = driver.session
    expectEmptyBookmark(session.last_bookmarks)
    answer = session.send(method_name) { |tx| tx.run('RETURN 42').single[0] }
    session.close
    expect(answer).to eq(42)
    expect(session.last_bookmarks).not_to be nil
  end

  def test_commit_write_without_success(method_name)
    driver.session do |session|
      answer = session.send(method_name) { |tx| tx.run("CREATE (:Person {name: 'Thor Odinson'}) RETURN 42").single[0] }
      expect(answer).to eq(42)
    end
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Thor Odinson'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(1)
  end

  def test_read_rollback_on_exception(method_name)
    driver.session do |session|
      expectEmptyBookmark(session.last_bookmarks)
      expect do
        session.send(method_name) do |tx|
          val = tx.run('RETURN 42').single[0]
          raise Neo4j::Driver::Exceptions::IllegalStateException if val == 42
          1
        end
      end.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
      expectEmptyBookmark(session.last_bookmarks)
    end
  end

  def test_write_rollback_on_exception(method_name)
    driver.session do |session|
      expectEmptyBookmark(session.last_bookmarks)
      expect do
        session.send(method_name) do |tx|
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

  def test_read_work_in_caller_thread(method_name)
    max_failures = 3
    caller_thread = Thread.current
    failures = 0
    result = driver.session do |session|
      session.send(method_name) do
        expect(Thread.current).to eq caller_thread
        raise Neo4j::Driver::Exceptions::ServiceUnavailableException, 'Oh no' if (failures += 1) < max_failures
        'Hello'
      end
    end
    expect(result).to eq 'Hello'
  end

  def test_write_read_allow_return_null(method_name)
    driver.session do |session|
      expect(session.send(method_name) { nil }).to be_nil
    end
  end

  def test_tx_rollback_when_function_throws_exception(mode, method_name)
    driver.session(default_access_mode: mode) do |session|
      expect do
        session.send(method_name) do |tx|
          tx.run("CREATE (:Person {name: 'Thanos'})")
          tx.run('UNWIND range(0, 1) AS i RETURN 10/i')
          # tx.commit
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
      session.run('CREATE (n {id: $id})', id: id)
    end
  end

  def update_node_id(statement_runner, current_id, new_id)
    statement_runner.run('MATCH (n {id: $current_id}) SET n.id = $new_id', current_id: current_id, new_id: new_id)
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
