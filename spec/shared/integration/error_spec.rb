# frozen_string_literal: true

# Ported from neo4j-java-driver ErrorIT.java
RSpec.describe 'Error' do
  let(:session) { driver.session }
  after(:example) { session.close }

  it 'throws a helpful syntax error from session.run' do
    expect { session.run('invalid query').consume }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException) do |e|
        expect(e.code).to match(/SyntaxError/)
        expect(e.message).to match(/^Invalid input/)
      end
  end

  it 'allows a new query after a recoverable error in the same session' do
    expect { session.run('invalid').consume }
      .to raise_error(Neo4j::Driver::Exceptions::ClientException)
    expect(session.run('RETURN 1').single[0]).to eq 1
  end

  it 'allows a new transaction after a recoverable error in a prior transaction' do
    session.begin_transaction do |tx|
      expect { tx.run('invalid').consume }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException)
    end
    session.begin_transaction do |tx|
      expect(tx.run('RETURN 1').single[0]).to eq 1
      tx.commit
    end
  end

  it 'explains the connection error when the bolt port is unreachable' do
    Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7777', basic_auth_token) do |d|
      expect { d.verify_connectivity }
        .to raise_error(Neo4j::Driver::Exceptions::ServiceUnavailableException) do |e|
          expect(e.message)
            .to start_with('Unable to connect to localhost:7777')
            .and include('ensure the database is running')
        end
    end
  end

  it 'gives a helpful error when bolt is pointed at the HTTP port' do
    Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7474', basic_auth_token, encryption: false) do |d|
      expect { d.verify_connectivity }
        .to raise_error(Neo4j::Driver::Exceptions::ClientException) do |e|
          expect(e.message).to start_with('Server responded HTTP.')
        end
    end
  end

  # Java's shouldHandleFailureAtRunTime — create a unique-name constraint
  # twice; the second create raises an EquivalentSchemaRuleAlreadyExists
  # ClientException mentioning the constraint's property.
  it 'surfaces a schema-rule clash at run time' do
    label = "Lbl#{SecureRandom.hex(6)}"
    create = "CREATE CONSTRAINT FOR (a:`#{label}`) REQUIRE a.name IS UNIQUE"
    session.begin_transaction do |tx|
      tx.run(create)
      tx.commit
    end
    begin
      session.begin_transaction do |tx|
        expect { tx.run(create).consume }
          .to raise_error(Neo4j::Driver::Exceptions::ClientException) do |e|
            expect(e.code).to eq 'Neo.ClientError.Schema.EquivalentSchemaRuleAlreadyExists'
            expect(e.message).to include('name')
          end
      end
    ensure
      session.run("DROP CONSTRAINT FOR (a:`#{label}`) REQUIRE a.name IS UNIQUE").consume rescue nil
    end
  end
end
