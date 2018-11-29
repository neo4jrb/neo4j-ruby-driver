RSpec.describe Neo4j::Driver do
  subject do
    session = driver.session
    session.write_transaction { |tx| tx.run("RETURN $param", param: param).single.first }
  ensure
    session&.close
  end

  context 'hash' do
    let(:param) { { key: 1 } }

    it { is_expected.to eq param }
  end

  context 'deep hash' do
    let(:param) { { key: { inner: %w[abc def] } } }

    it { is_expected.to eq param }
  end

  context 'array' do
    let(:param) { %w[abc def] }

    it { is_expected.to eq param }
  end

  context 'true' do
    let(:param) { true }

    it { is_expected.to eq param }
  end

  context 'false' do
    let(:param) { false }

    it { is_expected.to eq param }
  end

  context 'nil' do
    let(:param) { nil }

    it { is_expected.to eq nil }
  end

  context 'Integer' do
    let(:param) { 1 }

    it { is_expected.to eq 1 }
  end

  context 'Float' do
    let(:param) { 1.1 }

    it { is_expected.to eq 1.1 }
  end
end