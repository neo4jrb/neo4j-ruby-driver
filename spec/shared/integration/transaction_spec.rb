# frozen_string_literal: true

RSpec.describe 'Transaction' do
  let(:session) { driver.session }
  after(:example) { session.close }

  it 'runs and commits' do
    session.begin_transaction do |tx|
      tx.run('CREATE (n:FirstNode)')
      tx.run('CREATE (n:SecondNode)')
      tx.commit
    end
    expect(session.run('MATCH (n) RETURN count(n)').single['count(n)']).to eq 2
  end

  it 'runs and rolls back by default' do
    session.begin_transaction do |tx|
      tx.run('CREATE (n:FirstNode)')
      tx.run('CREATE (n:SecondNode)')
    end
    expect(session.run('MATCH (n) RETURN count(n)').single['count(n)']).to be_zero
  end

  it 'retrieves results' do
    session.run("CREATE (n {name:'Steve Brook'})")
    session.begin_transaction do |tx|
      expect(tx.run('MATCH (n) RETURN n.name').single['n.name']).to eq 'Steve Brook'
    end
  end

  it 'does not allow session level statement when there is a transaction' do
    session.begin_transaction
    expect { session.run('anything') }.to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'is closed after rollback' do
    tx = session.begin_transaction
    tx.close

    expect(tx).not_to be_open
  end

  it 'is closed after commit' do
    tx = session.begin_transaction
    tx.commit
    tx.close

    expect(tx).not_to be_open
  end

  it 'is open before commit' do
    tx = session.begin_transaction

    expect(tx).to be_open
  end

  it 'raises when rolling back a committed tx' do
    tx = session.begin_transaction
    tx.commit

    expect(&tx.method(:rollback)).to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'raises when rolling back a rolled-back tx' do
    tx = session.begin_transaction
    tx.rollback

    expect(&tx.method(:rollback)).to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'handles nil parameters gracefully' do
    session.run('match (n) return count(n)', nil)
  end

  it 'handles failure after closing transaction' do
    tx = session.begin_transaction
    tx.run('CREATE (n) RETURN n').consume
    tx.commit
    tx.close

    expect { session.run('CREAT (n) RETURN n').consume }.to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'handles nil Record/Value/Map parameters' do
    session.begin_transaction do |tx|
      tx.run('CREATE (n:FirstNode)')
      tx.commit
    end
  end

  it 'Rolls back Transaction After Failed Run And Commit And Session Successfully Begins New Transaction' do
    tx = session.begin_transaction
    expect { tx.run('invalid') }.to raise_error Neo4j::Driver::Exceptions::ClientException
    expect(&tx.method(:commit)).to raise_error Neo4j::Driver::Exceptions::ClientException

    session.begin_transaction do |another_tx|
      expect(another_tx.run('RETURN 1').single['1']).to eq 1
    end
  end

  it 'rolls back tx if error with consume' do
    expect do
      session.begin_transaction do |tx|
        result = tx.run('invalid')
        tx.commit
        result.consume
      end
    end.to raise_error Neo4j::Driver::Exceptions::ClientException

    session.begin_transaction do |another_tx|
      expect(another_tx.run('RETURN 1').single['1']).to eq 1
    end
  end

  it 'fails run' do
    session.begin_transaction do |tx|
      expect { tx.run('RETURN Wrong') }.to raise_error(Neo4j::Driver::Exceptions::ClientException) do |error|
        expect(error.code).to match /SyntaxError/
      end
    end
  end

  # Not Implemented
  # shouldBeResponsiveToThreadInterruptWhenWaitingForResult
  # shouldBeResponsiveToThreadInterruptWhenWaitingForCommit
  # shouldThrowWhenConnectionKilledDuringTransaction
  # shouldThrowWhenConnectionKilledDuringTransactionMarkedForSuccess

  it 'disallows queries after failure when results are consumed' do
    session.begin_transaction do |tx|
      expect(tx.run('UNWIND [1,2,3] AS x CREATE (:Node) RETURN x').map(&:first)).to eq [1, 2, 3]
      expect { tx.run('RETURN unknown').consume }.to raise_error(Neo4j::Driver::Exceptions::ClientException) do |error|
        expect(error.code).to match /SyntaxError/
      end
      expect { tx.run('CREATE (:OtherNode)').consume }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException, /^Cannot run more queries in this transaction/)
      expect { tx.run('RETURN 42').consume }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException, /^Cannot run more queries in this transaction/)
    end

    expect(count_nodes_by_label(:Node)).to be_zero
    expect(count_nodes_by_label(:OtherNode)).to be_zero
  end

  it 'rolls back when marked successful but one statement fails' do
    expect do
      session.begin_transaction do |tx|
        tx.run('CREATE (:Node1)')
        tx.run('CREATE (:Node2)')
        tx.run('CREATE SmthStrange')
        # In java the code below might be or might be not executed as all `tx.run` are responding asynchronously and the
        # exception might happen before any of the 3 subsequent lines is executed.
        tx.run('CREATE (:Node3)')
        tx.run('CREATE (:Node4)')

        tx.commit
      end
    end.to raise_error(Neo4j::Driver::Exceptions::ClientException) do |error|
      expect(error.code).to match /SyntaxError/
      # corresponding java test is not deterministic
      # expect(error.suppressed.size).to be >= 1
      # suppressed = error.suppressed.first
      # expect(suppressed).to be_a Neo4j::Driver::Exceptions::ClientException
      # expect(suppressed.message).to start_with "Transaction can't be committed"
    end

    expect(count_nodes_by_label(:Node1)).to be_zero
    expect(count_nodes_by_label(:Node2)).to be_zero
    expect(count_nodes_by_label(:Node3)).to be_zero
    expect(count_nodes_by_label(:Node4)).to be_zero
  end

  it 'accepts metadata on begin_transaction' do
    metadata = { foo: 'bar', baz: 1 }
    session.begin_transaction(metadata: metadata) do |tx|
      result = tx.run('CALL tx.getMetaData()').single.first
      expect(result).to eq metadata
      tx.commit
    end
  end

  it 'accepts timeout on begin_transaction (seconds)' do
    # Just verifies the kwarg is accepted and a normal query runs;
    # exercising the actual server-side timeout would need a long
    # query and be flaky.
    session.begin_transaction(timeout: 10) do |tx|
      expect(tx.run('RETURN 1').single.first).to eq 1
      tx.commit
    end
  end

  # --- Ported from neo4j-java-driver TransactionIT.java ---

  it 'allows run rollback and close' do
    session.begin_transaction do |tx|
      tx.run('CREATE (n:FirstNode)')
      tx.run('CREATE (n:SecondNode)')
      tx.rollback
    end
    expect(session.run('MATCH (n) RETURN count(n)').single['count(n)']).to eq 0
  end

  it 'allows run close and close' do
    session.begin_transaction do |tx|
      tx.run('CREATE (n:FirstNode)')
      tx.run('CREATE (n:SecondNode)')
      tx.close
    end
    expect(session.run('MATCH (n) RETURN count(n)').single['count(n)']).to eq 0
  end

  it 'is closed after close' do
    tx = session.begin_transaction
    tx.close
    expect(tx).not_to be_open
  end

  it 'fails to commit after commit' do
    tx = session.begin_transaction
    tx.run('CREATE (:MyLabel)')
    tx.commit
    expect(&tx.method(:commit))
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Can't commit.*committed/)
  end

  it 'fails to commit after rolled back' do
    tx = session.begin_transaction
    tx.run('CREATE (:MyLabel)')
    tx.rollback
    expect(&tx.method(:commit))
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Can't commit.*rolled back/)
  end

  it 'fails to commit after failure' do
    tx = session.begin_transaction
    xs = tx.run('UNWIND [1,2,3] AS x CREATE (:Node) RETURN x').to_a.map { |r| r[0] }
    expect(xs).to eq [1, 2, 3]
    expect { tx.run('RETURN unknown').consume }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException) { |e| expect(e.code).to match(/SyntaxError/) }
    expect(&tx.method(:commit))
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Transaction can't be committed.*rolled back/)
  end

  it 'fails to run query after tx is closed' do
    tx = session.begin_transaction
    tx.close
    expect { tx.run('RETURN 1') }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Cannot run more queries.*rolled back/)
  end

  it 'fails to run query after tx is committed' do
    tx = session.begin_transaction
    tx.commit
    expect { tx.run('RETURN 1') }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Cannot run more queries.*committed/)
  end

  it 'fails to run query after tx is rolled back' do
    tx = session.begin_transaction
    tx.rollback
    expect { tx.run('RETURN 1') }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Cannot run more queries.*rolled back/)
  end

  def count_nodes_by_label(label)
    session.run("MATCH (n:#{label}) RETURN count(n)").single.first
  end
end
