# frozen_string_literal: true

RSpec.describe 'Session' do
  describe 'thread interrupted after acquiring connection' do
    context 'with thread#raise' do
      it 'releases connection back into pool' do
        driver = Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
        session = driver.session
        session.read_transaction {}
        
        channel_pool = DriverInternalDataAccessor.channel_pool_from_session(session)
        expect(channel_pool.busy?).to be false

        thr = Thread.new do
          thr_session = driver.session
          thr_session.read_transaction { |_tx| sleep(60) }
        end

        wait_till { channel_pool.busy? }
        expect(channel_pool.busy?).to be true

        thr.raise("Bhadako!")

        wait_till { !channel_pool.busy? }
        expect(channel_pool.busy?).to be false
      end
    end

    context 'with thread#kill' do
      it 'releases connection back into pool' do
        driver = Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
        session = driver.session
        session.read_transaction {}
        
        channel_pool = DriverInternalDataAccessor.channel_pool_from_session(session)
        expect(channel_pool.busy?).to be false

        thr = Thread.new do
          thr_session = driver.session
          thr_session.read_transaction { |_tx| sleep(60) }
        end

        wait_till { channel_pool.busy? }
        expect(channel_pool.busy?).to be true
        thr.kill

        wait_till { !channel_pool.busy? }
        expect(channel_pool.busy?).to be false
      end
    end
  end
end
