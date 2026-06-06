# frozen_string_literal: true

# Ported from neo4j-java-driver ErrorIT.java
RSpec.describe 'Error' do
  let(:session) { driver.session }
  after(:example) { session.close }

  it 'throws helpful syntax error' do
    expect { session.run('invalid query').consume }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException) do |e|
        expect(e.code).to match(/SyntaxError/)
        expect(e.message).to match(/^Invalid input/)
      end
  end

  it 'allows new query after recoverable error' do
    expect { session.run('invalid').consume }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException)
    expect(session.run('RETURN 1').single[0]).to eq 1
  end

  it 'allows new transaction after recoverable error' do
    session.begin_transaction do |tx|
      expect { tx.run('invalid').consume }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException)
    end
    session.begin_transaction do |tx|
      expect(tx.run('RETURN 1').single[0]).to eq 1
      tx.commit
    end
  end

  it 'explains connection error' do
    Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7777', basic_auth_token) do |d|
      expect { d.verify_connectivity }
        .to raise_error(Neo4j::Driver::Exceptions::ServiceUnavailableException) do |e|
          expect(e.message)
            .to start_with('Unable to connect to localhost:7777')
            .and include('ensure the database is running')
        end
    end
  end

  it 'gets helpful error when trying to connect to http port' do
    Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7474', basic_auth_token, encryption: false) do |d|
      expect { d.verify_connectivity }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException) do |e|
          expect(e.message).to start_with('Server responded HTTP.')
        end
    end
  end

  # Java's shouldHandleFailureAtRunTime — create a labelled constraint,
  # then create it again; the second run raises a ClientException whose
  # message names both the label and the property. Java uses a random
  # label to avoid cross-test clashes; here a fixed test-specific label
  # is unambiguous within the suite and lets us pre-drop any leftover for
  # re-runnability without a finally (Java has none).
  it 'handles failure at run time' do
    label = 'ErrorItRunTimeFailure'
    create = "CREATE CONSTRAINT FOR (a:`#{label}`) REQUIRE a.name IS UNIQUE"
    leftover = session.run('SHOW CONSTRAINTS YIELD name, labelsOrTypes WHERE $l IN labelsOrTypes RETURN name',
                           l: label).to_a.first
    session.run("DROP CONSTRAINT #{leftover[:name]} IF EXISTS").consume if leftover
    session.begin_transaction do |tx|
      tx.run(create)
      tx.commit
    end
    session.begin_transaction do |tx|
      expect { tx.run(create).consume }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException) do |e|
          expect(e.message).to include(label).and include('name')
        end
    end
  end
end
