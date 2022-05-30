# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  describe 'param' do
    subject do
      driver.session do |session|
        session.write_transaction { |tx| tx.run('RETURN $param', param: param).single.first }
      end
    end

    context 'when Date' do
      let(:date) { '2018-04-05' }
      let(:param) { Date.parse(date) }

      it { is_expected.to eq param }
    end

    context 'when DateTime as Time' do
      let(:param) { Time.now.in_time_zone(TZInfo::Timezone.get('UTC')).change(zone: '+07:00') }

      it { is_expected.to eq param }
    end

    context 'when DateTime as plain Time' do
      let(:param) { Time.now }

      it { is_expected.to be_a Time }
      it { is_expected.to eq param }
    end

    context 'when DateTime as DateTime' do
      let(:param) { DateTime.now }

      it { is_expected.to be_a Time }
      it { is_expected.to eq param }
    end
  end

  describe 'cypher functions' do
    subject do
      driver.session do |session|
        session.write_transaction { |tx| tx.run("RETURN #{function}").single.first }
      end
    end

    context 'when Date' do
      let(:date) { '2018-04-05' }
      let(:function) { %{date("#{date}")} }
      let(:result) { Date.parse(date) }

      it { is_expected.to eq result }
    end

    context 'when DateTime with zone' do
      let(:datetime) { '2018-04-05T12:34:00' }
      let(:zone) { 'Europe/Berlin' }
      let(:function) { %{datetime("#{datetime}[#{zone}]")} }
      let(:result) { ActiveSupport::TimeZone.new(zone).parse(datetime) }

      it { is_expected.to eq result }
    end

    context 'when DateTime with offset and no zone' do
      let(:datetime) { '2018-12-05T12:34:00+01:00' }
      let(:function) { %{datetime("#{datetime}")} }
      let(:result) { ActiveSupport::TimeZone.new('Europe/Berlin').parse('2018-12-05T12:34:00') }

      it { is_expected.to eq result }
    end

    context 'when DateTime with offset and zone' do
      let(:datetime) { '2018-04-05T12:34:00+02:00' }
      let(:zone) { 'Europe/Berlin' }
      let(:function) { %{datetime("#{datetime}[#{zone}]")} }
      let(:result) { ActiveSupport::TimeZone.new('Europe/Berlin').parse('2018-04-05T12:34:00') }

      it { is_expected.to eq result }
    end

    context 'when epochMillis' do
      let(:function) { 'datetime({epochMillis: 3360000})' }
      let(:result) { ActiveSupport::TimeZone.new('UTC').parse('1970-01-01 00:56:00') }

      it { is_expected.to eq result }
    end
  end

  describe 'datetime roundtrip ruby check' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          dt = tx.run('RETURN datetime($param)', param: param).single.first
          dt == tx.run('RETURN $param', param: dt).single.first
        end
      end
    end

    context 'when dst DateTime with zone' do
      let(:param) { '2018-07-05T12:34:00[Europe/Berlin]' }

      it { is_expected.to be true }
    end

    context 'when winter DateTime with zone' do
      let(:param) { '2018-01-05T12:34:00[Europe/Berlin]' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset' do
      let(:param) { '2018-12-05T12:34:00+01:00' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset and zone' do
      let(:param) { '2018-04-05T12:34:00+02:00[Europe/Berlin]' }

      it { is_expected.to be true }
    end

    context 'when epochMillis' do
      let(:param) { { epochMillis: 3_360_000 } }

      it { is_expected.to be true }
    end
  end

  describe 'datetime roundtrip neo4j check' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          dt = tx.run('RETURN datetime($param)', param: param).single.first
          tx.run('RETURN datetime($param) = $dt', param: param, dt: dt).single.first
        end
      end
    end

    context 'when dst DateTime with zone' do
      let(:param) { '2018-07-05T12:34:00[Europe/Berlin]' }

      it { is_expected.to be true }
    end

    context 'when winter DateTime with zone' do
      let(:param) { '2018-01-05T12:34:00[Europe/Berlin]' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset -1' do
      let(:param) { '2018-12-05T12:34:00-01:00' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset +1' do
      let(:param) { '2018-12-05T12:34:00+01:00' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset +0' do
      let(:param) { '2018-12-05T12:34:00+00:00' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset Z' do
      let(:param) { '2018-12-05T12:34:00Z' }

      it { is_expected.to be true }
    end

    context 'when DateTime with offset and zone' do
      let(:param) { '2018-04-05T12:34:00+02:00[Europe/Berlin]' }

      it { is_expected.to be true }
    end

    context 'when epochMillis' do
      let(:param) { { epochMillis: 3_360_000 } }

      it { is_expected.to be true }
    end

    context 'when nanosecond' do
      let(:param) { { epochSeconds: 1, nanosecond: 1 } }

      it { is_expected.to be true }
    end
  end
end
