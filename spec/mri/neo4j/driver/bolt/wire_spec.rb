# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Bolt::Wire do
  next unless Neo4j::Driver::Loader.mri?

  Structure = Neo4j::Driver::PackStream::Structure
  Message = Neo4j::Driver::Bolt::Message

  # The Wire is created post-handshake with the negotiated protocol; it only
  # uses it to configure the packer and customise hydration. A no-op double is
  # all the framing/hydration path needs.
  let(:protocol) do
    Class.new do
      def configure_packer(_packer); end
      def customize_hydration(_unpacker); end
    end.new
  end

  subject(:wire) { described_class.new(protocol) }

  # Frame a server message the way the wire reads it: chunk(s) + 0x00 0x00.
  # Built independently of the wire under test so receive isn't validated
  # against its own enqueue.
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

  describe '#receive' do
    it 'parses a single complete message' do
      out = wire.receive(success(server: 'Neo4j/5.0'))
      expect(out.size).to eq(1)
      expect(out.first).to be_a(Message::Success)
      expect(out.first.metadata).to eq(server: 'Neo4j/5.0')
    end

    it 'parses several messages from one feed, in order' do
      bytes = record([1]) + record([2]) + success(type: 'r')
      out = wire.receive(bytes)
      expect(out.map(&:class)).to eq([Message::Record, Message::Record, Message::Success])
      expect(out[0].fields).to eq([1])
      expect(out[1].fields).to eq([2])
    end

    it 'reassembles a message split across feeds (mid-chunk-body)' do
      bytes = success(server: 'x')
      head = bytes.byteslice(0, 3)
      tail = bytes.byteslice(3..)
      expect(wire.receive(head)).to eq([])      # partial — nothing yet
      out = wire.receive(tail)
      expect(out.size).to eq(1)
      expect(out.first.metadata).to eq(server: 'x')
    end

    it 'reassembles when split mid-chunk-header (1 byte at a time)' do
      bytes = success(answer: 42)
      collected = bytes.each_byte.flat_map { |b| wire.receive(b.chr.b) }
      expect(collected.size).to eq(1)
      expect(collected.first.metadata).to eq(answer: 42)
    end

    it 'skips a NOOP keepalive (bare 0x00 0x00)' do
      expect(wire.receive("\x00\x00".b)).to eq([])
    end

    it 'skips NOOPs interleaved with a real message' do
      bytes = "\x00\x00".b + success(ok: true) + "\x00\x00".b
      out = wire.receive(bytes)
      expect(out.size).to eq(1)
      expect(out.first.metadata).to eq(ok: true)
    end

    it 'handles a message whose chunks span a NOOP-free multi-chunk body' do
      big = { data: 'z' * 70_000 } # forces >1 chunk (max 65535)
      out = wire.receive(framed(Structure.new(Message::SUCCESS, [big])))
      expect(out.first.metadata[:data].bytesize).to eq(70_000)
    end

    it 'hydrates a Failure into the exception-mapping message' do
      out = wire.receive(framed(Structure.new(Message::FAILURE,
                                              [{ code: 'Neo.ClientError.Statement.SyntaxError', message: 'bad' }])))
      expect(out.first).to be_a(Message::Failure)
      expect(out.first.code).to eq('Neo.ClientError.Statement.SyntaxError')
    end
  end

  describe '#enqueue / #take_outbound' do
    it 'frames a message as [size][payload][end marker] with the raw packed payload' do
      wire.enqueue(Message.run('RETURN 1', {}, {}))
      bytes = wire.take_outbound

      size = bytes.byteslice(0, 2).unpack1('S>')
      payload = bytes.byteslice(2, size)
      expect(bytes.bytesize).to eq(2 + size + 2)
      expect(bytes[-2..].bytes).to eq([0, 0]) # end marker

      packer = Neo4j::Driver::PackStream::Packer.new
      packer.reset
      packer.pack_message(Message.run('RETURN 1', {}, {}))
      expect(payload).to eq(packer.bytes)
    end

    it 'accumulates several enqueues (pipelining) into one outbound blob' do
      one = described_class.new(protocol)
      one.enqueue(Message.reset)
      single = one.take_outbound

      wire.enqueue(Message.reset)
      wire.enqueue(Message.reset)
      expect(wire).to be_pending_outbound
      expect(wire.take_outbound).to eq(single + single)
      expect(wire).not_to be_pending_outbound
    end
  end
end
