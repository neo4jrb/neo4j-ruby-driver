# frozen_string_literal: true

require 'timeout'

RSpec.describe Neo4j::Driver::Bolt::RecordBuffer do
  subject(:buffer) { described_class.new(fetch_size: 4, high_watermark: 4, low_watermark: 2) }

  describe 'producer/consumer handoff' do
    it 'shifts records in order then nil at end of stream' do
      buffer.deliver_batch([:a, :b], has_more: true)
      buffer.finish
      expect(buffer.shift).to eq(:a)
      expect(buffer.shift).to eq(:b)
      expect(buffer.shift).to be_nil # exhausted
    end

    it 're-raises a stream failure to the consumer, after any records that preceded it' do
      err = Neo4j::Driver::Exceptions::ServiceUnavailableException.new('boom')
      buffer.fail(err, [:a])
      expect(buffer.shift).to eq(:a)             # record that preceded the failure
      expect { buffer.shift }.to raise_error(err) # then the failure
    end

    it 'blocks the consumer on an empty buffer until a batch arrives' do
      buffer # instantiate
      producer = Thread.new { sleep 0.05; buffer.deliver_batch([:late], has_more: true) }
      got = Timeout.timeout(2) { buffer.shift }
      expect(got).to eq(:late)
      producer.join
    end
  end

  describe 'unbounded queue (backpressure is the cursor watermark, not a bound)' do
    it 'never blocks delivery — the reader dispatches under the wire lock' do
      blocked = Thread.new { 100.times { |i| buffer.deliver_batch([i], has_more: true) } }
      Timeout.timeout(2) { blocked.join }
      expect(blocked).not_to be_alive
      expect(buffer.size).to eq(100)
    end
  end

  describe 'server→driver autopull (cursor-driven via pull_ready?/note_pull_issued)' do
    it 'a fresh buffer withholds pulls (first PULL already pipelined with RUN)' do
      expect(buffer.pull_ready?).to be(false)
    end

    it 'does not pull while the buffer is above the low watermark' do
      buffer.deliver_batch([1, 2, 3], has_more: true) # size 3 > low (2), in flight cleared
      expect(buffer.pull_ready?).to be(false)
    end

    it 'is pull-ready once a delivered batch sits at/below the low watermark' do
      buffer.deliver_batch([1, 2], has_more: true) # size 2 == low, in flight cleared
      expect(buffer.pull_ready?).to be(true)
    end

    it 'withholds another pull once one is noted in flight, until the next batch is delivered' do
      buffer.deliver_batch([1, 2], has_more: true)
      expect(buffer.pull_ready?).to be(true)
      buffer.note_pull_issued
      expect(buffer.pull_ready?).to be(false)            # in flight
      buffer.shift
      buffer.shift                                       # drain the batch (size 0)
      buffer.deliver_batch([3, 4], has_more: true)       # next batch → not in flight, size 2 == low
      expect(buffer.pull_ready?).to be(true)
    end

    it 'withholds further pulls after the server says no has_more' do
      buffer.deliver_batch([1, 2], has_more: false)
      expect(buffer.pull_ready?).to be(false)
    end
  end
end
