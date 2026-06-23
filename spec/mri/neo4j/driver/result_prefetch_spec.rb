# frozen_string_literal: true

require 'timeout'

# Unit coverage for Result's prefetch promotion (MRI-only): the first batch is
# drained synchronously, and on the first has_more the remaining batches are
# streamed by a background Bolt::Pump into a RecordBuffer. Single-batch results
# never promote. Uses a socket-free fake connection that serves a scripted
# response sequence to both the synchronous batch-1 reader and the pump.
RSpec.describe Neo4j::Driver::Result do
  Message = Neo4j::Driver::Bolt::Message

  def rec(*values) = Message::Record.new(values)
  def more         = Message::Success.new(has_more: true)
  def done(meta = {}) = Message::Success.new(meta)
  def fail!(code = 'Neo.ClientError.Statement.SyntaxError') = Message::Failure.new(code: code, message: 'boom')

  # Serves fetch_response from a scripted queue (thread-safe: the synchronous
  # cursor reads batch 1, then the pump thread reads the rest — never at once,
  # but a Queue keeps it safe regardless). Records sent PULL/DISCARD messages.
  let(:connection) do
    Class.new do
      attr_reader :sent

      def initialize(script)
        @queue = Thread::Queue.new
        script.each { |m| @queue.push(m) }
        @sent = []
        @mutex = Mutex.new
      end

      def fetch_response = @queue.pop
      def send_message(m) = @mutex.synchronize { @sent << m }
      def flush = nil
      def classify_failure(e) = e
      def protocol = self
      def build_pull(n:) = [:pull, n]
      def build_discard(n:) = [:discard, n]
    end
  end

  def result_for(script, fetch_size: 2, on_summary: nil, on_release: nil)
    described_class.new(connection.new(script), %i[n], fetch_size: fetch_size,
                        on_summary: on_summary, on_release: on_release)
  end

  it 'does not promote a single-batch result (no extra PULL, no pump)' do
    released = false
    result = result_for([rec(1), rec(2), done(bookmark: 'bm')], on_release: -> { released = true })

    expect(result.to_a.map { _1[:n] }).to eq([1, 2])
    expect(result.connection.sent).to be_empty   # no follow-up PULL/DISCARD
    expect(released).to be(true)                  # connection released on terminal
  end

  it 'promotes on the first has_more and streams every remaining batch' do
    summary = nil
    # batch1: 1,2 + has_more | batch2: 3,4 + has_more | batch3: 5 + done
    script = [rec(1), rec(2), more, rec(3), rec(4), more, rec(5), done(type: 'r')]
    result = result_for(script, on_summary: ->(s) { summary = s })

    got = Timeout.timeout(5) { result.to_a.map { _1[:n] } }
    expect(got).to eq([1, 2, 3, 4, 5])
    # one follow-up PULL per extra batch (batch2 sent by promote, batch3 by pump)
    expect(result.connection.sent).to eq([[:pull, 2], [:pull, 2]])
    expect(summary).not_to be_nil
  end

  it 'consume() on a promoted stream DISCARDs the rest and returns the summary' do
    # fetch_size 4 ⇒ high 8 / low 2, so after promotion the pump parks at
    # batch-2's has_more boundary (4 buffered, one peeked ⇒ 3 > low) instead of
    # auto-pulling — giving consume() a deterministic window to cancel. The pump
    # then DISCARDs and the server replies with the terminating SUCCESS.
    script = [rec(1), rec(2), more, rec(3), rec(4), rec(5), rec(6), more, done(bookmark: 'bm')]
    harvested = nil
    result = result_for(script, fetch_size: 4, on_summary: ->(s) { harvested = s })

    expect(result.next[:n]).to eq(1)   # triggers batch-1 drain
    expect(result.next[:n]).to eq(2)
    expect(Timeout.timeout(5) { result.has_next? }).to be(true) # promotes; pump parks at boundary

    Timeout.timeout(5) { result.consume }
    expect(result.connection.sent).to eq([[:pull, 4], [:discard, -1]])
    expect(harvested).not_to be_nil
  end

  it 'surfaces a failure that occurs in a prefetched batch' do
    # batch1 ok + has_more; batch2 fails mid-stream.
    script = [rec(1), more, rec(2), fail!]
    result = result_for(script)

    expect(result.next[:n]).to eq(1)
    expect do
      Timeout.timeout(5) { result.to_a }
    end.to raise_error(Neo4j::Driver::Exceptions::ClientException)
    expect(result.failed?).to be(true)
  end
end
