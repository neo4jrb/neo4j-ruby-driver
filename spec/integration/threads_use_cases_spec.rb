# frozen_string_literal: true

RSpec.describe 'Session' do
  describe 'thread interrupted after acquiring connection' do
    context 'with thread#raise' do
      it 'releases connection back into pool' do
        require 'pry'
        driver = Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
        session = driver.session
        session.read_transaction {}
        
        channel_pool = DriverInternalDataAccessor.channel_pool_from_session(session)
        expect(channel_pool.busy?).to be false

        thr = Thread.new { session.read_transaction { |_tx| sleep(60) } }

        wait_for { !channel_pool.busy? }
        expect(channel_pool.busy?).to be true
        binding.pry
        thr.raise("Bhadako!")

        wait_for { channel_pool.busy? }
        expect(channel_pool.busy?).to be false
      end
    end

    context 'with thread#raise' do
      it 'releases connection back into pool' do
        require 'pry'
        driver = Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
        session = driver.session
        session.read_transaction {}
        
        channel_pool = DriverInternalDataAccessor.channel_pool_from_session(session)
        expect(channel_pool.busy?).to be false

        thr = Thread.new { session.read_transaction { |_tx| sleep(60) } }

        wait_for { !channel_pool.busy? }
        expect(channel_pool.busy?).to be true
        binding.pry
        thr.kill

        wait_for { channel_pool.busy? }
        expect(channel_pool.busy?).to be false
      end
    end
  end
end
