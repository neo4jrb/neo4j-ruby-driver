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
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.read_transaction { |tx| tx.run("RETURN #{function}").single.first }
      end
    end

    let(:function) { %{localdatetime("#{localdatetime}")} }

    context 'when LocalDateTime' do
      let(:localdatetime) { '2018-1-1T12:34:00' }
      let(:result) { described_class.parse(localdatetime) }

      it { is_expected.to eq result }
    end
  end

  describe 'localdatetime roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.read_transaction do |tx|
          dt = tx.run('RETURN localdatetime($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    context 'when LocalDateTime' do
      let(:param) { '2018-1-1T12:34:00' }

      it { is_expected.to be true }
    end
  end

  describe 'localdatetime roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.read_transaction do |tx|
          dt = tx.run('RETURN localdatetime($param)', param: param).single.first
          tx.run('RETURN localdatetime($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    context 'when LocalDateTime' do
      let(:param) { '2018-1-1T12:34:00' }

      it { is_expected.to be true }
    end
  end
end
