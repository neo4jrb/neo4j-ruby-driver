# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Exceptions::ClientException do
  # Memgraph maps errors to base Neo4jException, not Neo4j's ClientException.
  it 'incorrect syntax', memgraph: false do
    expect do
      session = driver.session
      driver.session.run('CRETE ()').to_a
    ensure
      session&.close
    end.to raise_error described_class
  end
end
