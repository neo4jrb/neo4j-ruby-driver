# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  context 'StatementResult' do
    describe '#single' do
      subject do
        driver.session { |session| session.run("UNWIND [#{items}] as r RETURN r").single.first }
      end

      context '0 results' do
        let(:items) { '' }
        let(:message) { 'Cannot retrieve a single record, because this result is empty.' }

        it 'raises exception' do
          expect(&method(:subject)).to raise_error Neo4j::Driver::Exceptions::NoSuchRecordException, message
        end
      end

      context '1 result', ffi: true do
        let(:items) { '1' }

        it { is_expected.to eq 1 }
      end

      context '2 results' do
        let(:items) { '1, 2' }
        let(:message) { 'Expected a result with a single record, but this result ' \
          'contains at least one more. Ensure your query returns only one record.' }

        it 'raises exception' do
          expect(&method(:subject)).to raise_error Neo4j::Driver::Exceptions::NoSuchRecordException, message
        end
      end
    end
  end
end
