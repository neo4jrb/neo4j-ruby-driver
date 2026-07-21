# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::UUID do
  let(:value) { '550e8400-e29b-41d4-a716-446655440000' }

  subject(:uuid) { described_class.new(value) }

  it 'is a String subclass that reads as its canonical value' do
    expect(uuid).to be_a(String)
    expect(uuid.to_s).to eq(value)
    expect(uuid).to eq(value)
  end

  it 'stays a distinct type' do
    expect(uuid).to be_a(described_class)
    expect(value).not_to be_a(described_class)
  end

  describe 'value equality' do
    it 'is == and eql? another UUID with the same value' do
      expect(uuid).to eq(described_class.new(value))
      expect(uuid).to eql(described_class.new(value))
    end

    it 'differs from a UUID with another value' do
      expect(uuid).not_to eq(described_class.new('00000000-0000-0000-0000-000000000000'))
    end
  end

  describe 'hash contract' do
    it 'hashes equal for equal values, so it works as a Hash key' do
      expect(uuid.hash).to eq(described_class.new(value).hash)
      expect({ uuid => :found }[described_class.new(value)]).to eq(:found)
    end
  end
end
