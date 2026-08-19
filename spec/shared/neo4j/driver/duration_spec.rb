# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::Duration do
  describe '#to_s' do
    it 'zero-pads nanoseconds to 9 digits' do
      # Regression: an earlier impl appended nanos directly so 5ns
      # rendered as ".5S" — off by 9 orders of magnitude.
      expect(described_class.new(0, 0, 1, 5).to_s).to eq 'P0M0DT1.000000005S'
    end

    it 'omits the fractional part when nanoseconds are zero' do
      expect(described_class.new(0, 0, 1, 0).to_s).to eq 'P0M0DT1S'
    end
  end

  describe '#hash' do
    it 'matches == (eql?/hash contract)' do
      a = described_class.new(1, 2, 3, 4)
      b = described_class.new(1, 2, 3, 4)
      expect(a).to eql b
      expect(a.hash).to eq b.hash
    end
  end

  describe 'param' do
    subject(:result) do
      driver.session do |session|
        session.execute_read { |tx| tx.run('RETURN $param', param: param).single.first }
      end
    end

    context 'when nil' do
      let(:param) { nil }

      it { is_expected.to eq param }
    end

    context 'when 1 day' do
      let(:param) { described_class.new(0, 1, 0, 0) }

      it { is_expected.to eq param }
    end

    context 'when 1 second' do
      let(:param) { described_class.new(0, 0, 1, 0) }

      it { is_expected.to eq param }
    end

    context 'when 1.5 second' do
      let(:param) { described_class.new(0, 0, 1, 500_000_000) }

      it { is_expected.to eq param }
    end

    # Memgraph truncates durations to microsecond precision (999999999ns -> 999999000ns).
    context 'when -1 nanosecond', memgraph: false do
      let(:param) { described_class.new(0, 0, 0, -1) }

      it { is_expected.to eq param }
    end

    # Memgraph drops sub-microsecond nanoseconds (1ns -> 0).
    context 'when 1 nanosecond', memgraph: false do
      let(:param) { described_class.new(0, 0, 0, 1) }

      it { is_expected.to eq param }
    end

    context 'when 15 days 12 hours' do
      let(:param) { described_class.new(0, 15, 43_200, 0) }

      it { is_expected.to eq param }
    end

    # Memgraph normalizes months into days+seconds (1 month -> 30 days + 37746 seconds).
    context 'when 1 month (to test month normalization)', memgraph: false do
      let(:param) { described_class.new(1, 0, 0, 0) }

      it { is_expected.to eq param }
    end
  end

  describe 'cypher functions' do
    subject(:result) do
      driver.session do |session|
        session.execute_read { |tx| tx.run("RETURN duration('#{duration}')").single.first }
      end
    end

    # Memgraph only accepts P[nD]T[nH][nM][nS] duration strings; year/month designators are rejected.
    context 'when 1 year only', memgraph: false do
      let(:duration) { 'P1Y' }

      it { is_expected.to eq described_class.new(12, 0, 0, 0) }
    end

    # Memgraph only accepts P[nD]T[nH][nM][nS] duration strings; year/month designators are rejected.
    context 'when 1 year 2 months', memgraph: false do
      let(:duration) { 'P1Y2M' }

      it { is_expected.to eq described_class.new(14, 0, 0, 0) }
    end

    # Memgraph only accepts P[nD]T[nH][nM][nS] duration strings; year designator is rejected.
    context 'when 0.9 years (Neo4j normalizes to 10 months + extras)', memgraph: false do
      let(:duration) { 'P0.9Y' }

      it 'returns normalized duration' do
        expect(result).to be_a(described_class)
      end

      # Neo4j will normalize fractional years
      it 'has 10 months' do
        expect(result.parts[:months]).to eq 10
      end
    end

    # Memgraph only accepts P[nD]T[nH][nM][nS] duration strings; the month designator is rejected.
    context 'when half month (Neo4j normalizes to ~15 days)', memgraph: false do
      let(:duration) { 'P0.5M' }

      it 'returns normalized duration' do
        expect(result).to be_a(described_class)
      end

      # Neo4j normalizes 0.5 months to approximately 15 days
      it 'has 15 days' do
        expect(result.parts[:days]).to eq 15
      end
    end

    context 'when half day (Neo4j normalizes to 12 hours)' do
      let(:duration) { 'P0.5D' }

      it 'returns normalized duration' do
        expect(result).to be_a(described_class)
      end

      # Neo4j normalizes 0.5 days to 43200 seconds (12 hours)
      it 'has 43200 seconds' do
        expect(result.parts[:seconds]).to eq 43_200
      end
    end
  end

  shared_examples 'duration' do
    # Memgraph only accepts P[nD]T[nH][nM][nS] duration strings; year/month/week designators are rejected.
    context 'when duration with all components', memgraph: false do
      let(:param) { 'P1Y2M3W10DT12H45M30.01S' }

      it { is_expected.to be true }
    end

    context 'when negative seconds' do
      let(:param) { 'PT-1.7S' }

      it { is_expected.to be true }
    end

    # Memgraph only accepts P[nD]T[nH][nM][nS] duration strings; the month designator is rejected.
    context 'when half month', memgraph: false do
      let(:param) { 'P0.5M' }

      it { is_expected.to be true }
    end

    context 'when half day' do
      let(:param) { 'P0.5D' }

      it { is_expected.to be true }
    end
  end

  describe 'roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.execute_read do |tx|
          dt = tx.run('RETURN duration($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    it_behaves_like 'duration'
  end

  describe 'roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.execute_read do |tx|
          dt = tx.run('RETURN duration($param)', param: param).single.first
          tx.run('RETURN duration($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    it_behaves_like 'duration'
  end
end
