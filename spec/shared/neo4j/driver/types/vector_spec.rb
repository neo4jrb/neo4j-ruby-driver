# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::Vector do
  subject(:vector) { described_class.new(:int16, [1, -2, 32_767]) }

  it 'exposes its element type, length and elements' do
    expect(vector.element_type).to eq(:int16)
    expect(vector.length).to eq(3)
    expect(vector.size).to eq(3)
    expect(vector.to_a).to eq([1, -2, 32_767])
  end

  it 'holds the elements in their big-endian wire encoding' do
    expect(vector.data).to eq("\x00\x01\xff\xfe\x7f\xff".b)
  end

  {
    int8: [[-128, 0, 127], 1],
    int16: [[-32_768, 32_767], 2],
    int32: [[-2_147_483_648, 2_147_483_647], 4],
    int64: [[-9_223_372_036_854_775_808, 9_223_372_036_854_775_807], 8],
    float32: [[1.5, -0.25, Float::INFINITY], 4],
    float64: [[Math::PI, -0.0, Float::MAX], 8]
  }.each do |element_type, (elements, width)|
    it "round-trips #{element_type} elements through from_bytes" do
      vector = described_class.new(element_type, elements)

      expect(vector.data.bytesize).to eq(elements.size * width)
      expect(described_class.from_bytes(element_type, vector.data)).to eq(vector)
      expect(vector.to_a).to eq(elements)
    end
  end

  it 'packs Integer elements of a float vector as floats' do
    expect(described_class.new(:float64, [1, 2]).to_a).to eq([1.0, 2.0])
  end

  it 'rounds float32 elements to single precision' do
    expect(described_class.new(:float32, [0.1]).to_a.first).to eq([0.1].pack('g').unpack1('g'))
  end

  it 'keeps a NaN payload bit-exact from bytes to bytes' do
    signalling_nan = "\x7f\x88\x42\x25".b

    expect(described_class.from_bytes(:float32, signalling_nan).data).to eq(signalling_nan)
  end

  it 'builds an empty vector' do
    expect(described_class.new(:int8, []).length).to eq(0)
    expect(described_class.from_bytes(:float64, '').to_a).to eq([])
  end

  describe 'validation' do
    it 'rejects an unknown element type' do
      expect { described_class.new(:int128, [1]) }.to raise_error(ArgumentError, /Unknown vector element type :int128/)
      expect { described_class.from_bytes('f32', '') }.to raise_error(ArgumentError, /Unknown vector element type/)
    end

    it 'rejects integers outside the element type instead of wrapping them' do
      expect { described_class.new(:int8, [0, 128]) }
        .to raise_error(ArgumentError, 'int8 element 128 is not an Integer in -128..127')
      expect { described_class.new(:int16, [-32_769]) }.to raise_error(ArgumentError, /-32768\.\.32767/)
      expect { described_class.new(:int64, [2**63]) }.to raise_error(ArgumentError, /int64/)
    end

    it 'rejects non-Integer elements of an integer vector instead of truncating them' do
      expect { described_class.new(:int32, [1.5]) }.to raise_error(ArgumentError, /element 1\.5 is not an Integer/)
      expect { described_class.new(:int8, [nil]) }.to raise_error(ArgumentError, /element nil is not an Integer/)
    end

    it 'rejects data that is not a whole number of elements' do
      expect { described_class.from_bytes(:int32, "\x00\x01".b) }
        .to raise_error(ArgumentError, 'int32 vector data is 2 bytes, not a multiple of 4')
    end
  end

  describe 'value equality' do
    it 'is == and eql? a vector with the same element type and elements' do
      expect(vector).to eq(described_class.new(:int16, [1, -2, 32_767]))
      expect(vector).to eql(described_class.from_bytes(:int16, vector.data))
    end

    it 'differs from a vector with other elements or another element type' do
      expect(vector).not_to eq(described_class.new(:int16, [1, -2, 0]))
      expect(described_class.new(:int8, [1])).not_to eq(described_class.new(:int16, [1]))
    end

    it 'does not equal its elements array' do
      expect(vector).not_to eq([1, -2, 32_767])
    end

    it 'hashes equal for equal vectors, so it works as a Hash key' do
      expect({ vector => :found }[described_class.new(:int16, [1, -2, 32_767])]).to eq(:found)
    end
  end

  it 'renders the Cypher vector literal, like the Java driver' do
    expect(described_class.new(:int8, [1, 2, 3]).to_s).to eq('vector([1, 2, 3], 3, INTEGER8 NOT NULL)')
    expect(described_class.new(:float64, [1.5]).to_s).to eq('vector([1.5], 1, FLOAT64 NOT NULL)')
    expect(vector.inspect).to eq('#<Neo4j::Driver::Types::Vector vector([1, -2, 32767], 3, INTEGER16 NOT NULL)>')
  end
end
