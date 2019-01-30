# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  subject do
    session = driver.session
    session.write_transaction { |tx| tx.run('RETURN $param', param: param).single.first }
  ensure
    session&.close
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
end
