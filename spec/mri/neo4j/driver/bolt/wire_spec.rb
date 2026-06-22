# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Bolt::Wire do
  next unless Neo4j::Driver::Loader.mri?

  Structure = Neo4j::Driver::PackStream::Structure
  Message = Neo4j::Driver::Bolt::Message

  # Post-handshake the Wire only uses the protocol to configure the packer and
  # customise hydration. A no-op double is all the framing/hydration path needs.
  let(:protocol) do
    Class.new do
      def configure_packer(_packer); end
      def customize_hydration(_unpacker); end
    end.new
  end

  subject(:wire) { described_class.new(protocol) }

  # Records which responses the wire routed to it (a response visitor — the same
  # interface Message#accept dispatches to).
  def recorder
    Class.new do
      attr_reader :events

      def initialize = @events = []
      def on_record(m)  = @events << [:record, m]
      def on_success(m) = @events << [:success, m]
      def on_failure(m) = @events << [:failure, m]
      def on_ignored(m) = @events << [:ignored, m]
    end.new
  end

  # Frame a server message the way the wire reads it: chunk(s) + 0x00 0x00.
  def framed(structure)
    packer = Neo4j::Driver::PackStream::Packer.new
    packer.reset
    packer.pack_message(structure)
    data = packer.bytes
    out = String.new(encoding: Encoding::BINARY)
    offset = 0
    while offset < data.bytesize
      n = [data.bytesize - offset, 65_535].min
      out << [n].pack('S>') << data.byteslice(offset, n)
      offset += n
    end
    out << "\x00\x00".b
  end

  def success(meta = {}) = framed(Structure.new(Message::SUCCESS, [meta]))
  def record(values)     = framed(Structure.new(Message::RECORD, [values]))
  def failure(meta)      = framed(Structure.new(Message::FAILURE, [meta]))

  describe 'response-ordering FIFO' do
    it 'routes a reply to the handler the request registered' do
      h = recorder
      wire.enqueue(Message.reset, h)
      expect(wire.in_flight).to eq(1)
      wire.receive(success(server: 'Neo4j/5'))
      expect(h.events).to eq([[:success, h.events[0][1]]])
      expect(h.events[0][1].metadata).to eq(server: 'Neo4j/5')
      expect(wire.in_flight).to eq(0) # terminal popped the handler
    end

    it 'keeps a streaming request at the FIFO front across its RECORDs, then advances' do
      run = recorder
      pull = recorder
      wire.enqueue(Message.run('Q', {}, {}), run)   # one SUCCESS
      wire.enqueue(Message.pull(n: -1), pull)        # RECORDs then SUCCESS
      expect(wire.in_flight).to eq(2)

      wire.receive(success(fields: %w[n]) + record([1]) + record([2]) + success(type: 'r'))

      expect(run.events.map(&:first)).to eq([:success])              # RUN reply
      expect(pull.events.map(&:first)).to eq(%i[record record success]) # PULL reply
      expect(pull.events[0][1].fields).to eq([1])
      expect(wire.in_flight).to eq(0)
    end

    it 'routes a FAILURE to the front handler and pops it' do
      h = recorder
      wire.enqueue(Message.run('bad', {}, {}), h)
      wire.receive(failure(code: 'Neo.ClientError.Statement.SyntaxError', message: 'x'))
      expect(h.events.map(&:first)).to eq([:failure])
      expect(wire.in_flight).to eq(0)
    end

    it 'reassembles a reply split across feeds before dispatching' do
      h = recorder
      wire.enqueue(Message.reset, h)
      bytes = success(server: 'x')
      wire.receive(bytes.byteslice(0, 3))
      expect(h.events).to be_empty       # partial — not dispatched yet
      wire.receive(bytes.byteslice(3..))
      expect(h.events.map(&:first)).to eq([:success])
    end

    it 'skips NOOP keepalives without touching the handler' do
      h = recorder
      wire.enqueue(Message.reset, h)
      wire.receive("\x00\x00".b)              # NOOP
      expect(h.events).to be_empty
      expect(wire.in_flight).to eq(1)         # still awaiting
      wire.receive("\x00\x00".b + success({}) + "\x00\x00".b)
      expect(h.events.map(&:first)).to eq([:success])
    end

    it 'reassembles a multi-chunk (>65535) reply' do
      h = recorder
      wire.enqueue(Message.run('Q', {}, {}), h)
      wire.receive(framed(Structure.new(Message::SUCCESS, [{ data: 'z' * 70_000 }])))
      expect(h.events[0][1].metadata[:data].bytesize).to eq(70_000)
    end
  end

  describe '#enqueue / #take_outbound (framing)' do
    it 'frames a request as [size][payload][end marker] with the raw packed payload' do
      wire.enqueue(Message.run('RETURN 1', {}, {}), recorder)
      bytes = wire.take_outbound
      size = bytes.byteslice(0, 2).unpack1('S>')
      payload = bytes.byteslice(2, size)
      expect(bytes.bytesize).to eq(2 + size + 2)
      expect(bytes[-2..].bytes).to eq([0, 0])

      packer = Neo4j::Driver::PackStream::Packer.new
      packer.reset
      packer.pack_message(Message.run('RETURN 1', {}, {}))
      expect(payload).to eq(packer.bytes)
    end

    it 'accumulates several enqueues (pipelining) into one outbound blob' do
      single = described_class.new(protocol).tap { _1.enqueue(Message.reset, recorder) }.take_outbound
      wire.enqueue(Message.reset, recorder)
      wire.enqueue(Message.reset, recorder)
      expect(wire).to be_pending_outbound
      expect(wire.take_outbound).to eq(single + single)
      expect(wire).not_to be_pending_outbound
    end
  end
end
