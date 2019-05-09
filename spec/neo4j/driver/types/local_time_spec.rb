# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::LocalTime, ffi: true do
  describe '#<=>' do
    it 'smaller' do
      expect(described_class.parse('8:05:21.00001')).to be < described_class.parse('8:06:21.00001')
    end

    it 'addition should be modulo day' do
      local_time = described_class.parse('23:00')
      added_time = local_time + 2.hours
      expect(added_time).to be_kind_of described_class
      expect(added_time).to be < local_time
      expect(added_time).to eql described_class.parse('01:00')
    end

    it 'eql?' do
      expect(described_class.parse('2018-1-1 8:00')).to eql described_class.parse('2018-7-1 8:00')
    end
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.write_transaction { |tx| tx.run("RETURN #{function}").single.first }
      end
    end

    let(:function) { %{localtime("#{localtime}")} }

    context 'when LocalTime' do
      let(:localtime) { '12:34:00' }
      let(:result) { described_class.parse(localtime) }

      it { is_expected.to eq result }
    end
  end

  describe 'datetime roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          dt = tx.run('RETURN localtime($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    context 'when LocalTime' do
      let(:param) { '12:34:00' }

      it { is_expected.to be true }
    end
  end

  describe 'datetime roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          dt = tx.run('RETURN localtime($param)', param: param).single.first
          tx.run('RETURN localtime($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    context 'when LocalTime' do
      let(:param) { '12:34:00' }

      it { is_expected.to be true }
    end
  end
end
