# frozen_string_literal: true

# Unit coverage for Bolt::Message::Failure#to_exception — the GQL (Bolt 5.7+)
# error shape and the synthesis applied to a legacy { code, message } failure.
RSpec.describe Neo4j::Driver::Bolt::Message::Failure do
  Exceptions = Neo4j::Driver::Exceptions

  def exc(metadata) = described_class.new(metadata).to_exception

  describe 'GQL (Bolt 5.7+) failure' do
    let(:metadata) do
      {
        gql_status: '01N00',
        description: 'cool class - mediocre subclass',
        message: "Server ain't cool with this, John Doe!",
        neo4j_code: 'Neo.ClientError.User.Uncool',
        diagnostic_record: { _classification: 'CLIENT_ERROR', _status_parameters: { userName: 'John Doe' } }
      }
    end

    subject(:error) { exc(metadata) }

    it 'maps the class from neo4j_code and exposes the GQL fields' do
      expect(error).to be_a(Exceptions::ClientException)
      expect(error.code).to eq('Neo.ClientError.User.Uncool')
      expect(error.message).to eq("Server ain't cool with this, John Doe!")
      expect(error.gql_status).to eq('01N00')
      expect(error.status_description).to eq('cool class - mediocre subclass')
    end

    it 'fills the diagnostic-record defaults without clobbering server keys' do
      expect(error.diagnostic_record).to eq(
        OPERATION: '', OPERATION_CODE: '0', CURRENT_SCHEMA: '/',
        _classification: 'CLIENT_ERROR', _status_parameters: { userName: 'John Doe' }
      )
    end

    it 'maps a known classification and preserves the raw one' do
      expect(error.raw_classification).to eq('CLIENT_ERROR')
      expect(error.classification).to eq('CLIENT_ERROR')
    end

    it 'surfaces an unrecognised classification as raw-only (classification nil)' do
      e = exc(metadata.merge(diagnostic_record: { _classification: 'SECURITY_ERROR' }))
      expect(e.raw_classification).to eq('SECURITY_ERROR')
      expect(e.classification).to be_nil # backend maps nil → "UNKNOWN"
    end

    it 'has no code and is a plain Neo4jException when neo4j_code is absent' do
      e = exc(metadata.except(:neo4j_code))
      expect(e.code).to be_nil
      expect(e.instance_of?(Exceptions::Neo4jException)).to be(true)
    end

    it 'recurses into the cause chain' do
      e = exc(metadata.merge(cause: metadata.merge(neo4j_code: 'Neo.TransientError.X.Y', gql_status: '02N00')))
      expect(e.gql_cause).to be_a(Exceptions::TransientException)
      expect(e.gql_cause.gql_status).to eq('02N00')
      expect(e.gql_cause.gql_cause).to be_nil
    end
  end

  describe 'legacy { code, message } failure (synthesised GQL fields)' do
    subject(:error) { exc(code: 'Neo.TransientError.Oopsie.OhSnap', message: "Sever ain't cool with this!") }

    it 'keeps the legacy class/code/message' do
      expect(error).to be_a(Exceptions::TransientException)
      expect(error.code).to eq('Neo.TransientError.Oopsie.OhSnap')
      expect(error.message).to eq("Sever ain't cool with this!")
    end

    it 'synthesises the 50N42 status, default diagnostic record, and no classification/cause' do
      expect(error.gql_status).to eq('50N42')
      expect(error.status_description).to eq(
        'error: general processing exception - unexpected error. ' \
        "Sever ain't cool with this!"
      )
      expect(error.diagnostic_record).to eq(OPERATION: '', OPERATION_CODE: '0', CURRENT_SCHEMA: '/')
      expect(error.raw_classification).to be_nil
      expect(error.classification).to be_nil
      expect(error.gql_cause).to be_nil
    end
  end
end
