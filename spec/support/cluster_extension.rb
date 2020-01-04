# frozen_string_literal: true

require 'neo4j/driver/util/cc/cluster_control'
require 'neo4j/driver/util/cc/shared_cluster'

RSpec.shared_context "cluster_extension" do
  USER = 'neo4j'
  PASSWORD = 'password'
  CLUSTER_DIR = File.absolute_path('db/neo4j/test-cluster')
  NEO4J_VERSION = ENV['NEO4J_VERSION'] || '3.5.14'
  INITIAL_PORT = 20_000

  CORE_COUNT = 3
  READ_REPLICA_COUNT = 2

  let(:default_auth_token) { Neo4j::Driver::AuthTokens.basic(USER, PASSWORD) }
  let(:cluster) { Neo4j::Driver::Util::CC::SharedCluster.get }

  before(:context) do
    expect(Neo4j::Driver::Util::CC::ClusterControl).to be_boltkit_available
    if Neo4j::Driver::Util::CC::SharedCluster.exists?
      cluster.delete_data
    else
      Neo4j::Driver::Util::CC::SharedCluster.install(NEO4J_VERSION, CORE_COUNT, READ_REPLICA_COUNT, PASSWORD,
                                                     INITIAL_PORT, CLUSTER_DIR)
      Neo4j::Driver::Util::CC::SharedCluster.start
    end
  end

  after(:context) do
    break unless Neo4j::Driver::Util::CC::SharedCluster.exists?
    Neo4j::Driver::Util::CC::SharedCluster.stop
  ensure
    Neo4j::Driver::Util::CC::SharedCluster.remove
  end
end
