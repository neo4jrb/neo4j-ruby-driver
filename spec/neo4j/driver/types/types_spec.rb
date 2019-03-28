# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  subject do
    driver.session do |session|
      session.write_transaction { |tx| tx.run('RETURN $param', param: param).single.first }
    end
  end

  context 'when hash' do
    let(:param) { { key: 1 } }

    it { is_expected.to eq param }
  end

  context 'when deep hash' do
    let(:param) { { key: { inner: %w[abc def] } } }

    it { is_expected.to eq param }
  end

  context 'when array' do
    let(:param) { %w[abc def] }

    it { is_expected.to eq param }
  end

  context 'when true' do
    let(:param) { true }

    it { is_expected.to eq param }
  end

  context 'when false' do
    let(:param) { false }

    it { is_expected.to eq param }
  end

  context 'when nil' do
    let(:param) { nil }

    it { is_expected.to eq nil }
  end

  context 'when Integer' do
    let(:param) { 1 }

    it { is_expected.to eq 1 }
  end

  context 'when Float' do
    let(:param) { 1.1 }

    it { is_expected.to eq 1.1 }
  end

  context 'when String' do
    let(:param) { 'string' }

    it { is_expected.to match /^string$/ }
  end

  context 'when Duration' do
    let(:param) { ActiveSupport::Duration.days(1) }

    it { is_expected.to eq param }
  end

  WGS_84_CRS_CODE = 4326
  CARTESIAN_3D_CRS_CODE = 9157
  DELTA = 0.00001

  context 'when 2DPoint' do
    let(:param) { Neo4j::Driver::Point.new(srid: WGS_84_CRS_CODE, x: 2, y: 3) }

    it { is_expected.to be_a Neo4j::Driver::Point }
    its(:srid) { is_expected.to eq WGS_84_CRS_CODE }
    its(:x) { is_expected.to be_within(DELTA).of(2) }
    its(:y) { is_expected.to be_within(DELTA).of(3) }
  end

  context 'when 2DPoint implied' do
    let(:param) { Neo4j::Driver::Point.new(longitude: 2, latitude: 3) }

    its(:srid) { is_expected.to eq WGS_84_CRS_CODE }
    its(:x) { is_expected.to be_within(DELTA).of(2) }
    its(:y) { is_expected.to be_within(DELTA).of(3) }
  end

  context 'when 3DPoint' do
    let(:param) { Neo4j::Driver::Point.new(x: 2, y: 3, z: 4) }

    its(:srid) { is_expected.to eq CARTESIAN_3D_CRS_CODE }
    its(:x) { is_expected.to be_within(DELTA).of(2) }
    its(:y) { is_expected.to be_within(DELTA).of(3) }
    its(:z) { is_expected.to be_within(DELTA).of(4) }
  end

  context 'when bytes' do
    let(:bytes) { [1, 2, 3] }
    let(:param) { Neo4j::Driver::ByteArray.from_bytes(bytes) }

    it { is_expected.to eq param }
    its(:to_bytes) { is_expected.to eq bytes }
    it { is_expected.to be_a Neo4j::Driver::ByteArray }
  end
end
