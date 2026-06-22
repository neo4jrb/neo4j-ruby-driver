# frozen_string_literal: true

require 'timeout'
require 'async'

RSpec.describe Neo4j::Driver::Bolt::Pump do
  next unless Neo4j::Driver::Loader.mri?

  Message = Neo4j::Driver::Bolt::Message
  RecordBuffer = Neo4j::Driver::Bolt::RecordBuffer
  Executor = Neo4j::Driver::Bolt::Executor

  def rec(*values) = Message::Record.new(values)
  def more         = Message::Success.new(has_more: true)
  def done         = Message::Success.new({})

  # A socket-free response source. Emits a scripted first batch; each pull(n)
  # appends the next scripted batch (so has_more → pull → next batch). Records
  # the pull sizes for assertions.
  class FakeSource
    attr_reader :pulls

    def initialize(*batches)
      @pending = (batches.shift || []).dup
      @rest = batches
      @pulls = []
    end

    def next_response
      raise 'pump read past the scripted end' if @pending.empty?

      @pending.shift
    end

    def pull(n)
      @pulls << n
      @pending.concat(@rest.shift || [])
    end
  end

  it 'fills the buffer with one batch then ends (no pull needed)' do
    buffer = RecordBuffer.new(fetch_size: 4)
    source = FakeSource.new([rec(1), rec(2), done])
    described_class.new(source, buffer).run # synchronous: scripted, never blocks

    expect(buffer.shift.fields).to eq([1])
    expect(buffer.shift.fields).to eq([2])
    expect(buffer.shift).to be_nil
    expect(source.pulls).to be_empty
  end

  it 'paces a second batch through the watermark gate, in a background thread' do
    buffer = RecordBuffer.new(fetch_size: 4, high_watermark: 8, low_watermark: 2)
    source = FakeSource.new(
      [rec(1), rec(2), rec(3), rec(4), more], # batch 1 (size 4 > low 2 → pump waits)
      [rec(5), rec(6), done]                  # batch 2, after a pull
    )
    pump = described_class.new(source, buffer)
    handle = Executor.spawn { pump.run }

    got = Array.new(6) { Timeout.timeout(2) { buffer.shift.fields.first } }
    expect(got).to eq([1, 2, 3, 4, 5, 6])
    expect(Timeout.timeout(2) { buffer.shift }).to be_nil
    handle.join
    expect(source.pulls).to eq([4]) # exactly one follow-up PULL of fetch_size
  end

  it 'delivers buffered records then re-raises a stream failure' do
    buffer = RecordBuffer.new(fetch_size: 4)
    failure = Message::Failure.new(code: 'Neo.ClientError.Statement.SyntaxError', message: 'bad')
    described_class.new(FakeSource.new([rec(1), failure]), buffer).run

    expect(buffer.shift.fields).to eq([1])
    expect { buffer.shift }.to raise_error(Neo4j::Driver::Exceptions::ClientException)
  end

  it 'treats a cancel during backpressure as a clean shutdown, not a stream error' do
    buffer = RecordBuffer.new(fetch_size: 1, high_watermark: 1, low_watermark: 1)
    source = FakeSource.new([rec(1), rec(2), done])
    pump = described_class.new(source, buffer)
    handle = Executor.spawn { pump.run }

    sleep 0.05    # pump pushes rec(1) (fills bound 1), then parks pushing rec(2)
    pump.cancel   # closes the buffer → ClosedQueueError in the parked push

    expect(buffer.shift.fields).to eq([1])           # buffered record still delivered
    expect(Timeout.timeout(2) { buffer.shift }).to be_nil # clean end — NOT a raise
    handle.join
  end

  # Reactor path is CRuby-only (async/fiber-scheduler unsupported on JRuby,
  # where the thread pump above is the default) — scope this to CRuby.
  it 'runs as a fiber under a host scheduler (fiber-prefetch), no async API used',
     skip: (RUBY_PLATFORM == 'java' && 'reactor path is CRuby-only') do
    delivered = nil
    Async do
      buffer = RecordBuffer.new(fetch_size: 4)
      source = FakeSource.new([rec(:x), rec(:y), done])
      Executor.spawn { described_class.new(source, buffer).run } # → Fiber.schedule
      delivered = [buffer.shift.fields.first, buffer.shift.fields.first, buffer.shift]
    end
    expect(delivered).to eq([:x, :y, nil])
  end
end
