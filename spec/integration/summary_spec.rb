# frozen_string_literal: true

RSpec.describe 'Summary' do
  it 'contains basic metadata' do
    driver.session do |session|
      statement_text = 'UNWIND [1, 2, 3, 4] AS n RETURN n AS number LIMIT {limit}'
      statement_parameters = { limit: 10 }
      result = session.run(statement_text, statement_parameters)
      expect(result).to have_next
      summary = result.consume
      expect(result).not_to have_next
      expect(summary.statement_type).to eq Neo4j::Driver::Summary::StatementType::READ_ONLY
      expect(summary.statement.text).to eq statement_text
      expect(summary.statement.parameters).to eq statement_parameters
      expect(summary).not_to have_plan
      expect(summary).not_to have_profile
      expect(summary).to eq result.consume
    end
  end
end
