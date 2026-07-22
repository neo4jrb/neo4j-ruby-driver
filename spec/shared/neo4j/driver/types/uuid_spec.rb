# frozen_string_literal: true

# Runs on both flavors: described_class is java.util.UUID on JRuby and the
# opaque Neo4j::Driver::Types::UUID on MRI — same public contract.
RSpec.describe Neo4j::Driver::Types::UUID do
  let(:value) { '550e8400-e29b-41d4-a716-446655440000' }

  subject(:uuid) { described_class.from_string(value) }

  it 'builds from_string and reads back the canonical string' do
    expect(uuid.to_s).to eq(value)
  end

  it 'is an opaque value, not a String' do
    expect(uuid).not_to be_a(String)
    expect(uuid).not_to eq(value) # a UUID does not equal its bare string form
  end

  it 'is constructed via from_string, not new' do
    expect { described_class.new(value) }.to raise_error(StandardError)
  end

  describe 'value equality' do
    it 'is == and eql? another UUID with the same value' do
      expect(uuid).to eq(described_class.from_string(value))
      expect(uuid).to eql(described_class.from_string(value))
    end

    it 'differs from a UUID with another value' do
      expect(uuid).not_to eq(described_class.from_string('00000000-0000-0000-0000-000000000000'))
    end
  end

  describe 'hash contract' do
    it 'hashes equal for equal values, so it works as a Hash key' do
      expect(uuid.hash).to eq(described_class.from_string(value).hash)
      expect({ uuid => :found }[described_class.from_string(value)]).to eq(:found)
    end
  end
end
