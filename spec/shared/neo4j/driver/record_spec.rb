# frozen_string_literal: true

RSpec.describe 'Record' do
  subject(:record) do
    driver.session { |session| session.run('RETURN 1 AS a, 2 AS b').single }
  end

  it 'exposes symbol keys' do
    expect(record.keys).to eq %i[a b]
  end

  describe '#to_h' do
    it 'returns a symbol-keyed map (matching the field keys), not string keys' do
      expect(record.to_h).to eq(a: 1, b: 2)
    end
  end

  describe '#[]' do
    it 'looks up by symbol' do
      expect(record[:a]).to eq 1
    end

    it 'looks up by string too' do
      expect(record['b']).to eq 2
    end

    it 'looks up by positional index' do
      expect(record[0]).to eq 1
    end
  end
end
