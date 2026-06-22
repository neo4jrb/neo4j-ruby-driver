# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Bolt::RecordSource do
  # A connection double recording what the source asks of it.
  let(:protocol) do
    Class.new do
      def build_pull(extra) = [:pull, extra]
    end.new
  end

  let(:connection) do
    proto = protocol
    Class.new do
      attr_reader :sent, :flushes

      define_method(:protocol) { proto }
      def initialize = (@sent = []; @flushes = 0; @replies = [])
      def queue_reply(r) = @replies << r
      def fetch_response = @replies.shift
      def send_message(m) = @sent << m
      def flush = @flushes += 1
    end.new
  end

  subject(:source) { described_class.new(connection) }

  it 'reads the next reply straight from the connection' do
    connection.queue_reply(:a)
    connection.queue_reply(:b)
    expect(source.next_response).to eq(:a)
    expect(source.next_response).to eq(:b)
  end

  it 'pull(n) sends a version-built PULL of n and flushes (single reader, guarded writer)' do
    source.pull(1000)
    expect(connection.sent).to eq([[:pull, { n: 1000 }]])
    expect(connection.flushes).to eq(1)
  end
end
