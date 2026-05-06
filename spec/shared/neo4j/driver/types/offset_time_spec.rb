# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::OffsetTime do
  describe '#<=>' do
    it 'orders by wall clock when offset is the same' do
      expect(described_class.parse('8:05:21.00001-05:00')).to be < described_class.parse('8:06:21.00001-05:00')
    end

    it 'orders by underlying UTC instant when offsets differ' do
      # Same wall-clock 8:05:21.00001 in two timezones:
      #   -06:00 (e.g. Mexico City) → 14:05:21 UTC
      #   -05:00 (e.g. Cancun)      → 13:05:21 UTC
      # so the -06:00 reading is the *later* instant.
      expect(described_class.parse('8:05:21.00001-06:00')).to be > described_class.parse('8:05:21.00001-05:00')
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

    it '+ preserves sub-second precision and the offset' do
      result = described_class.parse('12:00:00+05:00') + 0.5
      expect(result.nanosecond).to eq 500_000_000
      expect(result.tz_offset_seconds).to eq 5 * 3600
    end

    it '#to_s round-trips a negative offset with non-zero minutes' do
      # Regression: integer floor-division on `tz_offset_seconds / 3600`
      # for -12600s gave hours=-4, formatting -03:30 as -04:30.
      expect(described_class.parse('12:34:56-03:30').to_s).to eq '12:34:56.000000000-03:30'
    end
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.execute_write { |tx| tx.run("RETURN #{function}").single.first }
      end
    end

    let(:function) { %{time("#{offset_time}")} }

    context 'when Time (UTC)' do
      let(:offset_time) { '12:34:00Z' }
      let(:result) { described_class.parse(offset_time) }

      it { is_expected.to eq result }
    end

    context 'when Time (+3:30)' do
      let(:offset_time) { '12:34:00+03:30' }
      let(:result) { described_class.parse(offset_time) }

      it { is_expected.to eq result }
    end
  end

  describe 'offset_time roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.execute_write do |tx|
          dt = tx.run('RETURN time($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    context 'when Time' do
      let(:param) { '12:34:00-05:00' }

      it { is_expected.to be true }
    end
  end

  describe 'offset_time roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.execute_write do |tx|
          dt = tx.run('RETURN time($param)', param: param).single.first
          tx.run('RETURN time($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    context 'when Time' do
      let(:param) { '12:34:00-05:00' }

      it { is_expected.to be true }
    end
  end
end
