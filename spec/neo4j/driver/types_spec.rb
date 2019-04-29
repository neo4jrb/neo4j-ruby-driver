# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  subject do
    driver.session do |session|
      session.write_transaction { |tx| tx.run('RETURN $param', param: param).single.first }
    end
  end

  context 'when hash', ffi: true do
    let(:param) { { key: 1 } }

    it { is_expected.to eq param }
  end

  context 'when deep hash', ffi: true do
    let(:param) { { key: { inner: %w[abc def] } } }

    it { is_expected.to eq param }
  end

  context 'when array', ffi: true do
    let(:param) { %w[abc def] }

    it { is_expected.to eq param }
  end

  context 'when true', ffi: true do
    let(:param) { true }

    it { is_expected.to eq param }
  end

  context 'when false', ffi: true do
    let(:param) { false }

    it { is_expected.to eq param }
  end

  context 'when nil', ffi: true do
    let(:param) { nil }

    it { is_expected.to eq nil }
  end

  context 'when Integer', ffi: true do
    let(:param) { 1 }

    it { is_expected.to eq 1 }
  end

  context 'when Float', ffi: true do
    let(:param) { 1.1 }

    it { is_expected.to eq 1.1 }
  end

  context 'when String', ffi: true do
    let(:param) { 'string' }

    it { is_expected.to match(/^string$/) }
  end

  context 'when Duration' do
    let(:param) { ActiveSupport::Duration.days(1) }

    it { is_expected.to eq param }
  end

  WGS_84_CRS_CODE = 4326
  CARTESIAN_3D_CRS_CODE = 9157
  DELTA = 0.00001

  context 'when 2DPoint explicit', ffi: true do
    let(:param) { Neo4j::Driver::Types::Point.new(srid: WGS_84_CRS_CODE, x: 2, y: 3) }

    it { is_expected.to be_a Neo4j::Driver::Types::Point }
    its(:srid) { is_expected.to eq WGS_84_CRS_CODE }
    its(:x) { is_expected.to be_within(DELTA).of(2) }
    its(:y) { is_expected.to be_within(DELTA).of(3) }
  end

  context 'when 2DPoint implied', ffi: true do
    let(:param) { Neo4j::Driver::Types::Point.new(longitude: 2, latitude: 3) }

    its(:srid) { is_expected.to eq WGS_84_CRS_CODE }
    its(:x) { is_expected.to be_within(DELTA).of(2) }
    its(:y) { is_expected.to be_within(DELTA).of(3) }
  end

  context 'when 3DPoint', ffi: true do
    let(:param) { Neo4j::Driver::Types::Point.new(x: 2, y: 3, z: 4) }

    its(:srid) { is_expected.to eq CARTESIAN_3D_CRS_CODE }
    its(:x) { is_expected.to be_within(DELTA).of(2) }
    its(:y) { is_expected.to be_within(DELTA).of(3) }
    its(:z) { is_expected.to be_within(DELTA).of(4) }
  end

  context 'when bytes', ffi: true do
    let(:bytes) { [1, 2, 3] }
    let(:param) { Neo4j::Driver::Types::ByteArray.from_bytes(bytes) }

    it { is_expected.to eq param }
    its(:to_bytes) { is_expected.to eq bytes }
    it { is_expected.to be_a Neo4j::Driver::Types::ByteArray }
  end
end
