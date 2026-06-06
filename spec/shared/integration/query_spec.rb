# frozen_string_literal: true

# Ported from neo4j-java-driver QueryIT.java — the bits not already
# covered by parameters_spec / transaction_spec / session_spec.
RSpec.describe 'Query' do
  let(:session) { driver.session }
  after(:example) { session.close }

  # Java's shouldFailForIllegalQueries asserts both illegal inputs in one
  # method. MRI now validates query text client-side (Internal::Validator),
  # matching the Java/JRuby behaviour, so this is portable across flavours.
  it 'fails for illegal queries' do
    expect { session.run(nil) }
      .to raise_error(ArgumentError, /Cypher query text should not be null/)
    expect { session.run('') }
      .to raise_error(ArgumentError, /Cypher query text should not be an empty string/)
  end
end
