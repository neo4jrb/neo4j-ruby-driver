# frozen_string_literal: true

require 'timeout'
require 'async'

RSpec.describe Neo4j::Driver::Bolt::Executor do
  next unless Neo4j::Driver::Loader.mri?

  describe 'without a Fiber scheduler (threaded host)' do
    it 'reports no reactor and runs the block on a separate thread' do
      expect(described_class.reactor?).to be(false)
      caller_thread = Thread.current
      ran_on = Queue.new
      handle = described_class.spawn { ran_on.push(Thread.current) }
      handle.join
      expect(Timeout.timeout(2) { ran_on.pop }).not_to eq(caller_thread)
    end
  end

  # The fiber path only runs under a host Fiber scheduler. We use the `async`
  # gem as a test scheduler — but async (and the fiber scheduler generally) is
  # unsupported on JRuby, where this driver's reactor path is never used (the
  # thread path above is the JRuby default). So scope these to CRuby.
  describe 'with a Fiber scheduler installed (reactor host)', skip: (RUBY_PLATFORM == 'java' && 'reactor path is CRuby-only') do
    it 'reports a reactor and runs the block as a fiber on the same thread' do
      result = {}
      Async do
        result[:reactor] = described_class.reactor?
        host_thread = Thread.current
        done = Thread::Queue.new
        described_class.spawn do
          result[:same_thread] = (Thread.current == host_thread)
          done.push(true)
        end
        done.pop # scheduler-aware; yields to let the spawned fiber run
      end
      expect(result[:reactor]).to be(true)
      expect(result[:same_thread]).to be(true)
    end
  end
end
