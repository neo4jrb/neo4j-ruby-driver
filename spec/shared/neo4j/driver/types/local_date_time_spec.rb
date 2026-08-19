# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::LocalDateTime do
  describe '#<=>' do
    it 'smaller' do
      expect(described_class.parse('2018-5-5 8:07:21.00001')).to be < described_class.parse('2018-5-6 8:06:21.00001')
    end

    it 'addition should switch date' do
      local_time = described_class.parse('2018-5-5 23:00')
      added_time = local_time + 2.hours
      expect(added_time).to be_kind_of described_class
      expect(added_time).to be > local_time
      expect(added_time).to eql described_class.parse('2018-5-6 01:00')
    end

    it 'eql?' do
      expect(described_class.parse('2018-7-1 8:00Z')).to eql described_class.parse('2018-7-1 8:00+05:00')
    end

    it '+ preserves sub-second precision' do
      base = described_class.parse('2026-01-01 00:00:00')
      result = base + 0.5
      expect(result.nanoseconds).to eq 500_000_000
      expect(result.epoch_seconds).to eq base.epoch_seconds
    end
  end

  describe '.from_time and components' do
    # Force a non-UTC host zone to prove the wall clock is captured and read
    # back zone-independently (regression: the old to_time rendered in the
    # reader's local zone, so the same value showed different clocks).
    around do |example|
      original = ENV.fetch('TZ', nil)
      ENV['TZ'] = 'America/New_York'
      example.run
    ensure
      ENV['TZ'] = original
    end

    # Alaska (UTC-9) Monday 22:00 — a different instant *and* clock from NY.
    let(:alaska_monday) { Time.new(2026, 1, 5, 22, 0, 0, '-09:00') }

    it 'captures the displayed wall clock, not the absolute instant' do
      ldt = described_class.from_time(alaska_monday)
      expect([ldt.year, ldt.month, ldt.day, ldt.hour, ldt.minute, ldt.second])
        .to eq [2026, 1, 5, 22, 0, 0]
    end

    it 'renders the same wall clock regardless of host TZ' do
      expect(described_class.from_time(alaska_monday).to_s).to eq '2026-01-05 22:00:00.000000000'
    end

    it 'preserves nanosecond precision' do
      time = alaska_monday + Rational(123_456_789, 1_000_000_000)
      expect(described_class.from_time(time).nanosecond).to eq 123_456_789
    end

    it 'agrees with parse of the same clock face' do
      expect(described_class.from_time(alaska_monday)).to eql described_class.parse('2026-01-05T22:00:00')
    end
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.execute_read { |tx| tx.run("RETURN #{function}").single.first }
      end
    end

    let(:function) { %{localdatetime("#{localdatetime}")} }
    let(:result) { described_class.parse(localdatetime) }

    # Memgraph rejects single-digit month/day; kept for Neo4j's lenient parsing.
    context 'when LocalDateTime (single-digit month/day)', memgraph: false do
      let(:localdatetime) { '2018-1-1T12:34:00' }

      it { is_expected.to eq result }
    end

    # Parallel zero-padded value that both Neo4j and Memgraph accept.
    context 'when LocalDateTime (zero-padded)' do
      let(:localdatetime) { '2018-01-01T12:34:00' }

      it { is_expected.to eq result }
    end
  end

  describe 'localdatetime roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.execute_read do |tx|
          dt = tx.run('RETURN localdatetime($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    # Memgraph rejects single-digit month/day; kept for Neo4j's lenient parsing.
    context 'when LocalDateTime (single-digit month/day)', memgraph: false do
      let(:param) { '2018-1-1T12:34:00' }

      it { is_expected.to be true }
    end

    # Parallel zero-padded value that both Neo4j and Memgraph accept.
    context 'when LocalDateTime (zero-padded)' do
      let(:param) { '2018-01-01T12:34:00' }

      it { is_expected.to be true }
    end
  end

  describe 'localdatetime roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.execute_read do |tx|
          dt = tx.run('RETURN localdatetime($param)', param: param).single.first
          tx.run('RETURN localdatetime($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    # Memgraph rejects single-digit month/day; kept for Neo4j's lenient parsing.
    context 'when LocalDateTime (single-digit month/day)', memgraph: false do
      let(:param) { '2018-1-1T12:34:00' }

      it { is_expected.to be true }
    end

    # Parallel zero-padded value that both Neo4j and Memgraph accept.
    context 'when LocalDateTime (zero-padded)' do
      let(:param) { '2018-01-01T12:34:00' }

      it { is_expected.to be true }
    end
  end
end
