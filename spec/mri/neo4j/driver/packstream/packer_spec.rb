# frozen_string_literal: true

RSpec.describe Neo4j::Driver::PackStream::Packer do
  next unless Neo4j::Driver::Loader.mri?

  # Protocol is only consulted for UUIDs; datetimes don't need it.
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

    it 'falls back to the offset form for an offset-shaped zone name' do
      bytes = packed(time_in(Struct.new(:name).new('+07:00')))

      expect(bytes.getbyte(1)).to eq(0x46)
      expect(bytes).not_to include('+07:00')
    end
  end
end
