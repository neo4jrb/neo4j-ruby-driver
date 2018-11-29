RSpec.describe Neo4j::Driver do
  describe 'param' do
    subject do
      session = driver.session
      session.write_transaction { |tx| tx.run('RETURN $param', param: param).single.first }
    ensure
      session&.close
    end

    context 'Date' do
      let(:date) { '2018-04-05' }
      let(:param) { Date.parse(date) }

      it { is_expected.to eq param }
    end
  end

  describe 'cypher functions' do
    subject do
      session = driver.session
      session.write_transaction { |tx| tx.run("RETURN #{function}").single.first }
    ensure
      session&.close
    end

    context 'Date' do
      let(:date) { '2018-04-05' }
      let(:function) { %Q{date("#{date}")} }
      let(:result) { Date.parse(date) }

      it { is_expected.to eq result }
    end
  end
end