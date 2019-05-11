# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::OffsetTime do
  describe '#<=>' do
    it 'smaller' do
      expect(described_class.parse('8:05:21.00001-05:00')).to be < described_class.parse('8:06:21.00001-05:00')
      expect(described_class.parse('8:05:21.00001-06:00')).to be < described_class.parse('8:05:21.00001-05:00')
    end

    it 'addition should be modulo day' do
      local_time = described_class.parse('23:00Z')
      added_time = local_time + 2.hours
      expect(added_time).to be_kind_of described_class
      expect(added_time).to be < local_time
      expect(added_time).to eql described_class.parse('01:00Z')
    end

    it 'eql?' do
      expect(described_class.parse('2018-1-1 8:00Z')).to eql described_class.parse('2018-7-1 8:00+00:00')
    end
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.write_transaction { |tx| tx.run("RETURN #{function}").single.first }
      end
    end

    let(:function) { %{time("#{offset_time}")} }

    context 'when OffsetTime (UTC)' do
      let(:offset_time) { '12:34:00Z' }
      let(:result) { described_class.parse(offset_time) }

      it { is_expected.to eq result }
    end

    context 'when OffsetTime (+3:30)' do
      let(:offset_time) { '12:34:00+03:30' }
      let(:result) { described_class.parse(offset_time) }

      it { is_expected.to eq result }
    end
  end

  describe 'offset_time roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          dt = tx.run('RETURN time($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    context 'when OffsetTime' do
      let(:param) { '12:34:00-05:00' }

      it { is_expected.to be true }
    end
  end

  describe 'offset_time roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          dt = tx.run('RETURN time($param)', param: param).single.first
          tx.run('RETURN time($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    context 'when OffsetTime' do
      let(:param) { '12:34:00-05:00' }

      it { is_expected.to be true }
    end
  end
end
