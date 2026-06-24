# frozen_string_literal: true

require 'timeout'

RSpec.describe Neo4j::Driver::Bolt::RecordBuffer do
  subject(:buffer) { described_class.new(fetch_size: 4, high_watermark: 4, low_watermark: 2) }

  describe 'producer/consumer handoff' do
    it 'shifts records in order then nil at end of stream' do
      buffer.push_record(:a)
      buffer.push_record(:b)
      buffer.finish
      expect(buffer.shift).to eq(:a)
      expect(buffer.shift).to eq(:b)
      expect(buffer.shift).to be_nil # exhausted
    end

    it 're-raises a stream failure to the consumer' do
      err = Neo4j::Driver::Exceptions::ServiceUnavailableException.new('boom')
      buffer.push_record(:a)
      buffer.fail(err)
      expect(buffer.shift).to eq(:a)             # buffered record still delivered
      expect { buffer.shift }.to raise_error(err) # then the failure
    end

    it 'blocks the consumer on an empty buffer until a record arrives' do
      buffer # instantiate
      producer = Thread.new { sleep 0.05; buffer.push_record(:late) }
      got = Timeout.timeout(2) { buffer.shift }
      expect(got).to eq(:late)
      producer.join
    end
  end

  describe 'driver→consumer backpressure (SizedQueue bound = high watermark)' do
    it 'blocks push when the buffer is full and resumes when the consumer drains' do
      4.times { |i| buffer.push_record(i) } # fills to high watermark (4)
      blocked = Thread.new { buffer.push_record(:overflow) }
      sleep 0.05
      expect(blocked).to be_alive # producer parked at the bound
      buffer.shift               # consumer frees a slot
      Timeout.timeout(2) { blocked.join }
      expect(blocked).not_to be_alive
    end
  end

  describe 'server→driver autopull (cursor-driven via pull_ready?/note_pull_issued)' do
    # The first PULL is pipelined with RUN, so a fresh buffer has one in flight.
    before { buffer.batch_complete(has_more: true) } # that reply seen; none in flight, more to come

    it 'a fresh buffer withholds pulls (first PULL already pipelined with RUN)' do
      fresh = described_class.new(fetch_size: 4, high_watermark: 4, low_watermark: 2)
      expect(fresh.pull_ready?).to be(false)
    end

    it 'does not pull while the buffer is above the low watermark' do
      buffer.push_record(1)
      buffer.push_record(2)
      buffer.push_record(3) # size 3 > low (2)
      expect(buffer.pull_ready?).to be(false)
    end

    it 'is pull-ready once drained to the low watermark' do
      buffer.push_record(1)
      buffer.push_record(2)
      buffer.push_record(3)
      buffer.shift # 3 → 2 (== low)
      expect(buffer.pull_ready?).to be(true)
    end

    it 'withholds another pull once one is noted in flight, until the batch completes' do
      buffer.push_record(1)
      buffer.push_record(2) # size 2 == low → ready
      expect(buffer.pull_ready?).to be(true)
      buffer.note_pull_issued
      expect(buffer.pull_ready?).to be(false)        # in flight
      buffer.shift                                   # drain one
      buffer.batch_complete(has_more: true)          # reply seen → not in flight
      expect(buffer.pull_ready?).to be(true)
    end

    it 'withholds further pulls after the server says no has_more' do
      buffer.batch_complete(has_more: false)
      expect(buffer.pull_ready?).to be(false)
    end
  end
end
