# frozen_string_literal: true

# JRuby-specific Vector behaviour. The flavour-agnostic contract (element type,
# to_a, ==, validation, to_s) is covered by spec/shared; here we assert the
# storage really is the native Java Vector and that the on-demand byte bridge
# keeps float bits exact.
RSpec.describe Neo4j::Driver::Types::Vector do
  it 'is stored as the native Java driver Vector, not a pure-Ruby object' do
    vector = described_class.new(:float32, [1.5, -0.25])

    expect(vector).to be_a(Java::OrgNeo4jDriverTypes::Vector)
    expect(vector.java_class.name).to eq('org.neo4j.driver.internal.InternalFloat32Vector')
  end

  %i[int8 int16 int32 int64 float32 float64].each do |element_type|
    it "round-trips a #{element_type} vector through the native vector and the byte bridge" do
      vector = described_class.new(element_type, [1, -1, 0])

      expect(vector.element_type).to eq(element_type)
      expect(vector.to_a).to eq([1, -1, 0])
      expect(described_class.from_bytes(element_type, vector.data)).to eq(vector)
    end
  end

  it 'keeps float bits exact through the native vector, including a signalling NaN payload' do
    bytes = "\x7f\x88\x42\x25\x3f\x80\x00\x00".b

    expect(described_class.from_bytes(:float32, bytes).data).to eq(bytes)
  end

  it 'delegates == and hash to the Java driver value-equality (NaN payloads canonicalised)' do
    quiet = described_class.from_bytes(:float32, "\x7f\xc0\x00\x00".b)
    signalling = described_class.from_bytes(:float32, "\x7f\x80\x00\x01".b)

    expect(quiet).to eq(signalling)
    expect(quiet.hash).to eq(signalling.hash)
  end
end
