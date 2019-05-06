# frozen_string_literal: true

RSpec.describe ActiveSupport::Duration, ffi: true do
  describe 'param' do
    subject do
      driver.session do |session|
        session.read_transaction { |tx| tx.run('RETURN $param', param: param).single.first }
      end
    end

    context 'when 1 day' do
      let(:param) { described_class.days(1) }

      it { is_expected.to eq param }
    end

    context 'when 1 second' do
      let(:param) { described_class.seconds(1) }

      it { is_expected.to eq param }
    end

    context 'when 1.5 second' do
      let(:param) { described_class.seconds(1.5) }

      it { is_expected.to eq param }
    end

    context 'when -1 nanosecond' do
      let(:param) { described_class.seconds(BigDecimal('-1e-9')) }

      it { is_expected.to eq param }
    end

    context 'when 1 nanosecond' do
      let(:param) { described_class.seconds(1e-9) }

      it { is_expected.to eq param }
    end

    context 'when half month' do
      let(:param) { described_class.years(BigDecimal('0.9')) }

      it { is_expected.to eq param }

      it 'should have 10 months' do
        expect(subject.parts[:months]).to eq 10
      end
    end

    context 'when half month' do
      let(:param) { described_class.months(0.5) }

      it { is_expected.to eq param }

      it 'should have 15 days' do
        expect(subject.parts[:days]).to eq 15
      end
    end

    context 'when half day' do
      let(:param) { described_class.days(0.5) }

      it { is_expected.to eq param }
    end
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.read_transaction { |tx| tx.run("RETURN duration('#{duration}')").single.first }
      end
    end

    context 'when 1 year only' do
      let(:duration) { 'P1Y' }
      let(:result) { described_class.years(1) }

      it { is_expected.to eq result }
    end

    context 'when 1 year 2 months' do
      let(:duration) { 'P1Y2M' }
      let(:result) { described_class.months(14) }

      it { is_expected.to eq result }
    end

    context 'when 0.9 years' do
      let(:duration) { 'P0.9Y' }
      let(:result) { described_class.years(BigDecimal('0.9')) }

      # it { is_expected.to eq result }
      # Bug in neo4j
      it { is_expected.to be_within(1e-9).of(result) }

      it 'should have 10 months' do
        expect(subject.parts[:months]).to eq 10
      end
    end

    context 'when half month' do
      let(:duration) { 'P0.5M' }
      let(:result) { described_class.months(0.5) }

      it { is_expected.to eq result }

      it 'should have 15 days' do
        expect(subject.parts[:days]).to eq 15
      end
    end

    context 'when half day' do
      let(:duration) { 'P0.5D' }
      let(:result) { described_class.days(0.5) }

      it { is_expected.to eq result }
    end
  end

  shared_examples 'duration' do
    context 'when duration with all components' do
      let(:param) { 'P1Y2M3W10DT12H45M30.01S' }

      it { is_expected.to be true }
    end

    context 'when negative seconds' do
      let(:param) { 'PT-1.7S' }

      it { is_expected.to be true }
    end

    context 'when half month' do
      let(:param) { 'P0.5M' }

      it { is_expected.to be true }
    end

    context 'when half day' do
      let(:param) { 'P0.5D' }

      it { is_expected.to be true }
    end
  end

  describe 'roundtrip ruby check', ffi: true do
    subject do
      driver.session do |session|
        session.read_transaction do |tx|
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
        session.read_transaction do |tx|
          dt = tx.run('RETURN duration($param)', param: param).single.first
          tx.run('RETURN duration($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end
    it_behaves_like 'duration'
  end
end
