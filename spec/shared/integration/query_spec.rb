# frozen_string_literal: true

# Ported from neo4j-java-driver QueryIT.java — the bits not already
# covered by parameters_spec / transaction_spec / session_spec.
RSpec.describe 'Query' do
  let(:session) { driver.session }
  after(:example) { session.close }

  it 'raises on a nil query (shouldFailForIllegalQueries)' do
    expect { session.run(nil) }
      .to raise_error(ArgumentError, /Cypher query text should not be null/)
  end

  it 'raises on an empty query (shouldFailForIllegalQueries)' do
    expect { session.run('') }
      .to raise_error(ArgumentError, /Cypher query text should not be an empty string/)
  end
end
