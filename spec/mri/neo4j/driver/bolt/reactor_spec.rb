# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Bolt::Reactor do
  next unless Neo4j::Driver::Loader.mri?

  subject(:reactor) { described_class.new }

  after { reactor.stop }

  describe 'owned reactor (no ambient scheduler)' do
    it 'runs the block on a dedicated background thread, not the caller thread' do
      caller_thread = Thread.current
      ran_on = reactor.run_and_wait { Thread.current }
      expect(ran_on).to be_a(Thread)
      expect(ran_on).not_to eq(caller_thread)
    end

    it 'keeps a single reactor thread across runs' do
      first  = reactor.run_and_wait { Thread.current }
      second = reactor.run_and_wait { Thread.current }
      expect(second).to eq(first)
    end

    it 'returns the block value and propagates exceptions' do
      expect(reactor.run_and_wait { 21 * 2 }).to eq(42)
      expect { reactor.run_and_wait { raise 'boom' } }.to raise_error('boom')
    end

    it 'stop joins the background thread' do
      thread = reactor.run_and_wait { Thread.current }
      reactor.stop
      expect(thread).not_to be_alive
    end
  end

  describe 'ambient reactor (called inside Async {})' do
    it 'runs the IO fibers on the existing reactor instead of a new thread' do
      outcome = nil
      Async do
        ambient_thread = Thread.current
        ran_on = reactor.run_and_wait { Thread.current }
        outcome = { ambient: ambient_thread, ran_on: ran_on }
      end
      expect(outcome[:ran_on]).to eq(outcome[:ambient])
    end

    it 'does not keep a one-shot Async {} block open (transient tasks)' do
      started = Async::Clock.now
      Async do |task|
        # a perpetual fiber like a connection reader
        reactor.run { loop { task.sleep 5 } }
        # real work finishes quickly
        reactor.run_and_wait { :done }
      end
      expect(Async::Clock.now - started).to be < 2
    end
  end
end
