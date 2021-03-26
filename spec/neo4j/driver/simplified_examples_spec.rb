# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  it 'Simplified Hello World without block' do
    begin
      session = driver.session
      greeting = session.run("CREATE (a:Greeting) SET a.message = $message RETURN a.message + ', from node ' + id(a)",
                             message: 'hello, world').single.first
      puts greeting
    ensure
      session&.close
    end

    expect(greeting).to match(/hello, world, from node \d+/)
  end

  it 'Simplified Hello World with block' do
    greeting = nil
    driver.session do |session|
      greeting = session.run("CREATE (a:Greeting) SET a.message = $message RETURN a.message + ', from node ' + id(a)",
                             message: 'hello, world').single.first
      puts greeting
    end
    expect(greeting).to match(/hello, world, from node \d+/)
  end

  it 'Simplified Hello World with 0 arity block' do
    greeting = nil
    driver.session do
      greeting = run("CREATE (a:Greeting) SET a.message = $message RETURN a.message + ', from node ' + id(a)",
                     message: 'hello, world').single.first
      puts greeting
    end
    expect(greeting).to match(/hello, world, from node \d+/)
  end

  it 'Driver with block and fetching before session close' do
    username = 'neo4j'
    password = 'password'
    result = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(username, password)) do |driver|
      driver.session { |session| session.run('CREATE (a:Person {name: $name}) RETURN a.name', name: 'John').single }
    end

    expect(result.first).to eq 'John'
  end

  it 'raises type mismatch error read_transaction' do
    driver.session do |session|
      expect do
        session.read_transaction do |tx|
          tx.run('MATCH (r) MATCH ()-[r]-() RETURN r')
        end
      end.to raise_error(Neo4j::Driver::Exceptions::ClientException, /Type mismatch:/)
    end
  end

  it 'raises type mismatch error in explicit transaction on close' do
    driver.session do |session|
      tx = session.begin_transaction
      tx.run('MATCH (r) MATCH ()-[r]-() RETURN r')
      expect(&tx.method(:close)).to raise_error(Neo4j::Driver::Exceptions::ClientException, /Type mismatch:/)
    end
  end

  %i[consume peek has_next? to_a keys single].each do |method|
    it "raises type mismatch error in explicit transaction on #{method}" do
      driver.session do |session|
        tx = session.begin_transaction
        expect { tx.run('MATCH (r) MATCH ()-[r]-() RETURN r').send(method) }
          .to raise_error(Neo4j::Driver::Exceptions::ClientException, /Type mismatch:/)
      ensure
        expect { tx.close }.not_to raise_error
      end
    end
  end

  it 'raise exception on delete without detach' do
    driver.session do |session|
      session.write_transaction do |tx|
        tx.run('CREATE (:Label)-[:REL]->()')
      end
      expect do
        session.write_transaction do |tx|
          tx.run('MATCH (l:Label) DELETE l')
        end
      end.to raise_error(Neo4j::Driver::Exceptions::ClientException, /Cannot delete/)
      # Neo4j::Driver::Exceptions::ClientException: Cannot delete node<6>, because it still has relationships. To delete this node, you must first delete its relationships.
    end
  end

  it 'accepts transaction config', version: '>=3.5' do
    driver.session do |session|
      session.read_transaction(timeout: 1.minute, metadata: { a: 1, b: 'string' }) do |tx|
        expect(tx.run('RETURN 1').single.first).to eq 1
      end
    end
  end

  it 'accepts run config', version: '>=3.5' do
    driver.session do |session|
      expect(session.run('RETURN 1', {}, timeout: 1.minute, metadata: { a: 1, b: 'string' }).single.first).to eq 1
    end
  end

  describe 'multibyte characters' do
    it 'accepts in query' do
      driver.session do |session|
        expect(session.run('RETURN "Düsseldorf"').single.first).to eq 'Düsseldorf'
      end
    end

    it 'accepts in parameter' do
      driver.session do |session|
        expect(session.run('RETURN $Straße', Straße: 'Münchener').single.first).to eq 'Münchener'
      end
    end
  end
end
