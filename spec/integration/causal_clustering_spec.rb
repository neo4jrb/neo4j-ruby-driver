# frozen_string_literal: true

require 'timeout'
require 'support/cluster_extension'

RSpec.describe 'CausalClusteringSpec' do
  include_context 'cluster_extension'

  DEFAULT_TIMEOUT = 120

  def new_session(mode)
    driver.session(mode)
  end

  it 'executes reads and writes when driver supplied with address of leader ' do
    count = execute_write_and_read_through_bolt(cluster.leader)
    expect(count).to eq 1
  end

  it '...' do

  end

  it 'executes reads and writes when driver supplied with address of follower ' do
    count = execute_write_and_read_through_bolt(cluster.any_follower)
    expect(count).to eq 1
  end

  private

  def execute_write_and_read_through_bolt(member)
    create_driver(member.routing_uri) do |driver|
      in_expirable_session do
        driver.session(Neo4j::Driver::AccessMode::WRITE, &method(:execute_write_and_read))
      end
    end
  end

  def create_driver(bolt_uri, &block)
    Neo4j::Driver::GraphDatabase.driver(bolt_uri, default_auth_token, &block)
  end

  def execute_write_and_read(session)
    session.run("MERGE (n:Person {name: 'Jim'})").consume
    session.run('MATCH (n:Person) RETURN COUNT(*) AS count').next['count']
  end

  def in_expirable_session
    Timeout.timeout(DEFAULT_TIMEOUT, nil, 'Transaction did not succeed in time') do
      yield
    rescue Neo4j::Driver::Exceptions::SessionExpiredException, Neo4j::Driver::Exceptions::ServiceUnavailableException
      # role might have changed; try again
      sleep(0.5)
      retry
    end
  end
end
