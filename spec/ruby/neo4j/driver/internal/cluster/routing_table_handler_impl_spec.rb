RSpec.describe Neo4j::Driver::Internal::Cluster::RoutingTableHandlerImpl do
  let(:routing_table) { instance_double(Neo4j::Driver::Internal::Cluster::ClusterRoutingTable) }
  let(:rediscovery) { instance_double(Neo4j::Driver::Internal::Cluster::RediscoveryImpl) }
  let(:connection_pool) { instance_double(Neo4j::Driver::Internal::Async::Pool::ConnectionPoolImpl) }
  let(:routing_table_registry) { instance_double(Neo4j::Driver::Internal::Cluster::RoutingTableRegistryImpl) }
  let(:logger) { instance_double(Logger) }
  let(:routing_table_purge_delay) { 30 }
  let(:address) { instance_double(Neo4j::Driver::Internal::BoltServerAddress, to_s: "localhost:7687") }
  
  subject do
    described_class.new(routing_table, rediscovery, connection_pool, routing_table_registry, logger, routing_table_purge_delay)
  end

  describe '#on_connection_failure' do
    it 'removes server from all routing table lists' do
      expect(routing_table).to receive(:forget).with(address)
      subject.on_connection_failure(address)
    end
  end

  describe '#on_write_failure' do
    it 'removes server from writers list only' do
      expect(routing_table).to receive(:forget_writer).with(address)
      subject.on_write_failure(address)
    end

    it 'keeps server available for reads when NotALeader error occurs' do
      expect(routing_table).to receive(:forget_writer).with(address)
      subject.on_write_failure(address)
    end
  end
end
