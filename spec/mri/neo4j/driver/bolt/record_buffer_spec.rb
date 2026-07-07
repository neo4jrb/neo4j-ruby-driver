# frozen_string_literal: true

require 'timeout'

RSpec.describe Neo4j::Driver::Bolt::RecordBuffer do
  subject(:buffer) { described_class.new(fetch_size: 4, high_watermark: 4, low_watermark: 2) }

  describe 'incremental producer/consumer handoff' do
    it 'hands out records in order, :empty when momentarily drained, :ended at close' do
      buffer.push_record(:a)
      buffer.push_record(:b)
      expect(buffer.try_shift).to eq(:a)
      expect(buffer.try_shift).to eq(:b)
      expect(buffer.try_shift).to eq(:empty) # drained but stream still open
      buffer.finish
      expect(buffer.try_shift).to eq(:ended)
    end

    it 'delivers records before raising a stream failure' do
      err = Neo4j::Driver::Exceptions::ServiceUnavailableException.new('boom')
      buffer.push_record(:a)
      buffer.fail(err)
      expect(buffer.try_shift).to eq(:a)            # record that preceded the failure
      expect { buffer.try_shift }.to raise_error(err) # then the failure
    end
  end

  describe '#await — one wait woken by a record OR the batch promise' do
    it 'wakes when a record is delivered mid-stream' do
      producer = Thread.new { sleep 0.05; buffer.push_record(:late) }
      Timeout.timeout(2) { buffer.await }
      expect(buffer.try_shift).to eq(:late)
      producer.join
    end

    it 'wakes when the batch completes (promise resolves) with no new record' do
      # First PULL is in flight (@pull_in_flight true); a bare batch_complete
      # must release a cursor that has drained the buffer empty.
      producer = Thread.new { sleep 0.05; buffer.batch_complete(has_more: true) }
      Timeout.timeout(2) { buffer.await }
      expect(buffer.pull_ready?).to be(true) # cursor can now PULL the next batch
      producer.join
    end

    it 'returns immediately once the stream has ended' do
      buffer.finish
      Timeout.timeout(2) { buffer.await }
    end
  end

  describe 'server→driver autopull (cursor-driven via pull_ready?/note_pull_issued)' do
    it 'a fresh buffer withholds pulls (first PULL already pipelined with RUN)' do
      expect(buffer.pull_ready?).to be(false)
    end

    it 'does not pull while the buffer is above the low watermark' do
      3.times { |i| buffer.push_record(i) } # size 3 > low (2)
      buffer.batch_complete(has_more: true) # promise fulfilled
      expect(buffer.pull_ready?).to be(false)
    end

    it 'is pull-ready once the batch completes and the buffer is at/below the low watermark' do
      2.times { |i| buffer.push_record(i) } # size 2 == low
      buffer.batch_complete(has_more: true)
      expect(buffer.pull_ready?).to be(true)
    end

    it 'withholds another pull once one is noted in flight, until the next batch completes' do
      buffer.batch_complete(has_more: true)
      expect(buffer.pull_ready?).to be(true)
      buffer.note_pull_issued
      expect(buffer.pull_ready?).to be(false)  # promise unfulfilled again
      buffer.batch_complete(has_more: true)    # next batch's SUCCESS
      expect(buffer.pull_ready?).to be(true)
    end

    it 'withholds further pulls after the server says no has_more' do
      buffer.batch_complete(has_more: false)
      expect(buffer.pull_ready?).to be(false)
    end
  end
end
