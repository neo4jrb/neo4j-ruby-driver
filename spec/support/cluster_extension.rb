# frozen_string_literal: true

require 'neo4j/driver/util/cc/cluster_control'
require 'neo4j/driver/util/cc/shared_cluster'

RSpec.shared_context 'cluster_extension' do
  USER = 'neo4j'
  PASSWORD = 'pass'
  NEO4J_VERSION = ENV['NEO4J_VERSION'] || '4.3.4'
  CLUSTER_DIR = File.absolute_path("db/neo4j/test-cluster#{NEO4J_VERSION}")
  INITIAL_PORT = 20_000

  CORE_COUNT = 3
  READ_REPLICA_COUNT = 2

  let(:default_auth_token) { Neo4j::Driver::AuthTokens.basic(USER, PASSWORD) }

  def cluster
    Neo4j::Driver::Util::CC::SharedCluster.get
  end

  before(:context) do
    expect(Neo4j::Driver::Util::CC::ClusterControl).to be_boltkit_available
    if Neo4j::Driver::Util::CC::SharedCluster.exists?
    else
      Neo4j::Driver::Util::CC::SharedCluster.install(NEO4J_VERSION, CORE_COUNT, READ_REPLICA_COUNT, PASSWORD,
                                                     INITIAL_PORT, CLUSTER_DIR)
      Neo4j::Driver::Util::CC::SharedCluster.start
    end
    cluster.delete_data
  end

  after do
    cluster.start_offline_members
    cluster.delete_data
  end

  after(:context) do
    break unless Neo4j::Driver::Util::CC::SharedCluster.exists?
    Neo4j::Driver::Util::CC::SharedCluster.stop
  ensure
    Neo4j::Driver::Util::CC::SharedCluster.remove
  end
end
