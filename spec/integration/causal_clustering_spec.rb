# frozen_string_literal: true

require 'timeout'
require 'support/cluster_extension'

RSpec.describe 'CausalClusteringSpec' do
  include_context 'cluster_extension'

  DEFAULT_TIMEOUT = 120

  delegate :leader, :version3?, to: :cluster

  def new_session(mode)
    driver.session(mode)
  end

  it 'executes reads and writes when driver supplied with address of leader ' do
    count = execute_write_and_read_through_bolt(leader)
    expect(count).to eq 1
  end

  # DisabledOnNeo4jWith( BOLT_V4 )
  it 'executes reads and writes when router is discovered' do
    skip 'Not applicable to V4' unless version3?
    count = execute_write_and_read_through_bolt_on_first_available_address(cluster.any_read_replica, leader)
    expect(count).to eq 1
  end

  it 'executes reads and writes when driver supplied with address of follower ' do
    count = execute_write_and_read_through_bolt(cluster.any_follower)
    expect(count).to eq 1
  end

  # DisabledOnNeo4jWith( BOLT_V4 )
  it 'session creation fails if calling discovery procedure on edge server' do
    skip 'Not applicable to V4' unless version3?
    read_replica = cluster.any_read_replica
    expect { create_driver(read_replica.routing_uri) }
      .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException,
                      'Could not perform discovery. No routing servers available.'
  end

  # Ensure that Bookmarks work with single instances using a driver created using a bolt[not+routing] URI.
  it 'bookmarks work with driver pinned to single server' do
    create_driver(leader.bolt_uri) do |driver|
      bookmark = in_expirable_session(driver, ->(driver, &block) { driver.session(&block) }) do |session|
        session.begin_transaction do |tx|
          tx.run('CREATE (p:Person {name: $name })', name: 'Alistair')
          tx.success
        end
        session.last_bookmark
      end

      expect(bookmark).to be_present

      driver.session(bookmark) do |session|
        session.begin_transaction do |tx|
          record = tx.run('MATCH (n:Person) RETURN COUNT(*) AS count').next
          expect(record[:count]).to eq 1
        end
      end
    end
  end

  it 'uses bookmark from a read session in a write session' do
    create_driver(leader.bolt_uri) do |driver|
      in_expirable_session(driver, create_writable_session) do |session|
        session.run('CREATE (p:Person {name: $name })', name: 'Jim')
      end

      bookmark = nil
      driver.session(Neo4j::Driver::AccessMode::READ) do |session|
        session.begin_transaction do |tx|
          tx.run('MATCH (n:Person) RETURN COUNT(*) AS count').next
          tx.success
        end

        bookmark = session.last_bookmark
      end

      expect(bookmark).to be_present

      in_expirable_session(driver, create_writable_session(bookmark)) do |session|
        session.begin_transaction do |tx|
          tx.run('CREATE (p:Person {name: $name })', name: 'Alistair')
          tx.success
        end
      end

      driver.session do |session|
        record = session.run('MATCH (n:Person) RETURN COUNT(*) AS count').next
        expect(record[:count]).to eq 2
      end
    end
  end

  # needs implementation details. Impossible as integration test
  #it 'shouldDropBrokenOldConnections' do
  #end

  it 'begin transaction raises for invalid bookmark' do
    invalid_bookmark = 'hi, this is an invalid bookmark'

    create_driver(leader.bolt_uri) do |driver|
      driver.session(invalid_bookmark) do |session|
        expect { session.begin_transaction }
          .to raise_error Neo4j::Driver::Exceptions::ClientException, Regexp.new(invalid_bookmark)
      end
    end
  end

  it 'handles graceful leader switch' do
    create_driver(leader.routing_uri) do |driver|
      session1 = driver.session
      tx1 = session1.begin_transaction

      # gracefully stop current leader to force re-election
      cluster.stop(leader)

      tx1.run('CREATE (person:Person {name: $name, title: $title})', name: 'Webber', title: 'Mr')
      tx1.success

      expect(&tx1.method(:close)).to raise_error Neo4j::Driver::Exceptions::SessionExpiredException
      session1.close

      bookmark = in_expirable_session(driver, ->(driver, &block) { driver.session(&block) }) do |session|
        session.begin_transaction do |tx|
          tx.run('CREATE (person:Person {name: $name, title: $title})', name: 'Webber', title: 'Mr')
          tx.success
        end
        session.last_bookmark
      end

      driver.session(Neo4j::Driver::AccessMode::READ, bookmark) do |session2|
        session2.begin_transaction do |tx2|
          record = tx2.run('MATCH (n:Person) RETURN COUNT(*) AS count').next
          tx2.success
          expect(record[:count]).to eq 1
        end
      end
    end
  end

=begin
  it 'does not serve writes when majority of cores are dead' do
    create_driver(leader.routing_uri) do |driver|
      cores = cluster.cores
      cluster.followers.each(&cluster.method(:kill))
      #awaitLeaderToStepDown(cores);

      # now we should be unable to write because majority of cores is down
      10.times do
        expect do
          driver.session(Neo4j::Driver::AccessMode::WRITE) do |session|
            session.run("CREATE (p:Person {name: 'Gamora'})").consume
          end
        end.to raise_error Neo4j::Driver::Exceptions::SessionExpiredException
      end
    end
  end
=end

  it 'driver with resolver' do
    uri = URI(leader.bolt_uri)
    Neo4j::Driver::GraphDatabase.driver(
      'neo4j://wrong:9999',
      basic_auth_token,
      encryption: false,
      resolver: ->(_address) { [Neo4j::Driver::Net::ServerAddress.of(uri.host, uri.port)] }
    ) do |driver|
      driver.session { |session| expect(session.run('RETURN 1').single.first).to eq 1 }
    end
  end

  private

  def execute_write_and_read_through_bolt(member)
    create_driver(member.routing_uri) do |driver|
      in_expirable_session(driver, create_writable_session, &method(:execute_write_and_read))
    end
  end

  def execute_write_and_read_through_bolt_on_first_available_address(*members)
    discover_driver(members.map(&:routing_uri)) do |driver|
      in_expirable_session(driver, create_writable_session, &method(:execute_write_and_read))
    end
  end

  def create_writable_session(bookmark = nil)
    ->(driver, &block) { driver.session(Neo4j::Driver::AccessMode::WRITE, bookmark, &block) }
  end

  def create_driver(bolt_uri, config = config_without_logging, &block)
    Neo4j::Driver::GraphDatabase.driver(bolt_uri, default_auth_token, config, &block)
  end

  def config_without_logging
    { logger: ActiveSupport::Logger.new(IO::NULL), encryption: false }
  end

  def discover_driver(routing_uris, &block)
    Neo4j::Driver::GraphDatabase.routing_driver(routing_uris, default_auth_token, config_without_logging, &block)
  end

  def execute_write_and_read(session)
    session.run("MERGE (n:Person {name: 'Jim'})").consume
    session.run('MATCH (n:Person) RETURN COUNT(*) AS count').next['count']
  end

  def in_expirable_session(driver, acquirer, &block)
    Timeout.timeout(DEFAULT_TIMEOUT, nil, 'Transaction did not succeed in time') do
      acquirer.call(driver, &block)
    rescue Neo4j::Driver::Exceptions::SessionExpiredException, Neo4j::Driver::Exceptions::ServiceUnavailableException
      # role might have changed; try again
      sleep(0.5)
      retry
    end
  end
end
