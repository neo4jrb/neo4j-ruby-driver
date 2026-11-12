# frozen_string_literal: true

RSpec.describe Neo4j::Driver::PackStream::Packer do
  next unless Neo4j::Driver::Loader.mri?

  # Protocol is only consulted for UUIDs and vectors; datetimes don't need it.
  let(:packer) { described_class.new(nil) }
  # A Time that carries a `time_zone`, like ActiveSupport::TimeWithZone does.
  let(:zoned_time_class) { Class.new(Time) { attr_accessor :time_zone } }

  def packed(value)
    packer.reset
    packer.pack(value)
    packer.bytes
  end

  def time_in(zone)
    zoned_time_class.utc(2026, 1, 15, 12).tap { it.time_zone = zone }
  end

  describe 'DateTime zone id' do
    it 'sends the IANA identifier, not the Rails display name, for an ActiveSupport zone' do
      bytes = packed(time_in(ActiveSupport::TimeZone['Mountain Time (US & Canada)']))

      expect(bytes.getbyte(1)).to eq(0x66)
      expect(bytes).to include('America/Denver')
      expect(bytes).not_to include('Mountain Time')
    end

    it 'sends the identifier of a bare TZInfo zone' do
      bytes = packed(time_in(TZInfo::Timezone.get('Europe/Berlin')))

      expect(bytes.getbyte(1)).to eq(0x66)
      expect(bytes).to include('Europe/Berlin')
    end

    it 'keeps UTC verbatim rather than canonicalising it to Etc/UTC' do
      bytes = packed(time_in(ActiveSupport::TimeZone['UTC']))

      expect(bytes.getbyte(1)).to eq(0x66)
      expect(bytes).not_to include('Etc/UTC')
    end

    it 'falls back to the offset form for an offset-shaped zone name' do
      bytes = packed(time_in(Struct.new(:name).new('+07:00')))

      expect(bytes.getbyte(1)).to eq(0x46)
      expect(bytes).not_to include('+07:00')
    end
  end

  describe 'Vector' do
    let(:vector) { Neo4j::Driver::Types::Vector.new(:int16, [1, -2]) }

    def packed_with(protocol_class, value)
      described_class.new(protocol_class.new(nil, nil)).pack(value).bytes
    end

    it 'packs a Bolt 6.0 VECTOR struct: element-type marker and big-endian bytes, both as BYTES' do
      expect(packed_with(Neo4j::Driver::Bolt::Protocol::V6, vector))
        .to eq("\xB2\x56\xCC\x01\xC9\xCC\x04\x00\x01\xFF\xFE".b)
    end

    it 'uses the element-type marker of each element type' do
      markers = Neo4j::Driver::Types::Vector::ELEMENT_TYPES.keys.to_h do |element_type|
        [element_type, packed_with(Neo4j::Driver::Bolt::Protocol::V61,
                                   Neo4j::Driver::Types::Vector.new(element_type, [])).getbyte(4)]
      end

      expect(markers).to eq(int8: 0xC8, int16: 0xC9, int32: 0xCA, int64: 0xCB, float32: 0xC6, float64: 0xC1)
    end

    it 'rejects a vector before Bolt 6.0' do
      expect { packed_with(Neo4j::Driver::Bolt::Protocol::V58, vector) }
        .to raise_error(Neo4j::Driver::Exceptions::UnsupportedFeatureException,
                        'Vector type is not supported by this Bolt protocol version')
    end
  end
end
