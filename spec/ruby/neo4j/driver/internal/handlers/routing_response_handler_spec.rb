require 'neo4j/driver'

RSpec.describe Neo4j::Driver::Internal::Handlers::RoutingResponseHandler do
  let(:delegate) { double('delegate') }
  let(:address) { instance_double(Neo4j::Driver::Internal::BoltServerAddress, to_s: "localhost:7687") }
  let(:access_mode) { Neo4j::Driver::AccessMode::WRITE }
  let(:error_handler) { double('error_handler') }
  
  subject do
    described_class.new(delegate, address, access_mode, error_handler)
  end

  before do
    # Mock Futures.completion_exception_cause to just return the error as-is
    stub_const("#{described_class}::Futures", Class.new do
      def self.completion_exception_cause(error)
        error
      end
    end)
  end

  describe 'error handling' do
    before do
      allow(delegate).to receive(:on_failure)
    end

    context 'when ServiceUnavailableException occurs' do
      it 'calls on_connection_failure to remove server from routing table' do
        error = Neo4j::Driver::Exceptions::ServiceUnavailableException.new("Server unavailable")
        
        expect(error_handler).to receive(:on_connection_failure).with(address)
        
        subject.on_failure(error)
      end

      it 'transforms to SessionExpiredException' do
        error = Neo4j::Driver::Exceptions::ServiceUnavailableException.new("Server unavailable")
        allow(error_handler).to receive(:on_connection_failure)
        
        expect(delegate).to receive(:on_failure) do |new_error|
          expect(new_error).to be_a(Neo4j::Driver::Exceptions::SessionExpiredException)
          expect(new_error.message).to include("no longer available")
        end
        
        subject.on_failure(error)
      end
    end

    context 'when DatabaseUnavailable transient error occurs' do
      it 'calls on_connection_failure to remove server from routing table' do
        error = Neo4j::Driver::Exceptions::TransientException.new("Neo.TransientError.General.DatabaseUnavailable", "Database unavailable")
        
        expect(error_handler).to receive(:on_connection_failure).with(address)
        
        subject.on_failure(error)
      end
    end

    context 'when ProtocolException occurs' do
      it 'calls on_connection_failure to remove server from routing table' do
        error = Neo4j::Driver::Exceptions::ProtocolException.new("Protocol violation")
        
        expect(error_handler).to receive(:on_connection_failure).with(address)
        
        subject.on_failure(error)
      end

      it 'passes through the original error' do
        error = Neo4j::Driver::Exceptions::ProtocolException.new("Protocol violation")
        allow(error_handler).to receive(:on_connection_failure)
        
        expect(delegate).to receive(:on_failure).with(error)
        
        subject.on_failure(error)
      end
    end

    context 'when NotALeader error occurs in WRITE mode' do
      it 'calls on_write_failure which removes server from writers only' do
        error = Neo4j::Driver::Exceptions::ClientException.new("Neo.ClientError.Cluster.NotALeader", "Not a leader")
        
        expect(error_handler).to receive(:on_write_failure).with(address)
        
        subject.on_failure(error)
      end

      it 'transforms to SessionExpiredException' do
        error = Neo4j::Driver::Exceptions::ClientException.new("Neo.ClientError.Cluster.NotALeader", "Not a leader")
        allow(error_handler).to receive(:on_write_failure)
        
        expect(delegate).to receive(:on_failure) do |new_error|
          expect(new_error).to be_a(Neo4j::Driver::Exceptions::SessionExpiredException)
          expect(new_error.message).to include("no longer accepts writes")
        end
        
        subject.on_failure(error)
      end
    end

    context 'when ForbiddenOnReadOnlyDatabase error occurs in WRITE mode' do
      it 'calls on_write_failure which removes server from writers only' do
        error = Neo4j::Driver::Exceptions::ClientException.new("Neo.ClientError.General.ForbiddenOnReadOnlyDatabase", "Read only")
        
        expect(error_handler).to receive(:on_write_failure).with(address)
        
        subject.on_failure(error)
      end
    end

    context 'when write error occurs in READ mode' do
      let(:access_mode) { Neo4j::Driver::AccessMode::READ }

      it 'does not call on_write_failure' do
        error = Neo4j::Driver::Exceptions::ClientException.new("Neo.ClientError.Cluster.NotALeader", "Not a leader")
        
        expect(error_handler).not_to receive(:on_write_failure)
        
        subject.on_failure(error)
      end

      it 'returns ClientException about write in READ mode' do
        error = Neo4j::Driver::Exceptions::ClientException.new("Neo.ClientError.Cluster.NotALeader", "Not a leader")
        
        expect(delegate).to receive(:on_failure) do |new_error|
          expect(new_error).to be_a(Neo4j::Driver::Exceptions::ClientException)
          expect(new_error.message).to include("Write queries cannot be performed in READ access mode")
        end
        
        subject.on_failure(error)
      end
    end
  end
end
