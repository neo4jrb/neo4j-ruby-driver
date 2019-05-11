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
end
