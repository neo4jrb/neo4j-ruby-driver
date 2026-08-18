# frozen_string_literal: true

# Memgraph maps errors to base Neo4jException, not Neo4j's ClientException.
RSpec.describe Neo4j::Driver::Exceptions::ClientException, memgraph: false do
  it 'incorrect syntax' do
    expect do
      session = driver.session
      driver.session.run('CRETE ()').to_a
    ensure
      session&.close
    end.to raise_error described_class
  end
end
