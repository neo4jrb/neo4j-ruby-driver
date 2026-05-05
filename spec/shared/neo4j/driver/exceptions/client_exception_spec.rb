# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Exceptions::ClientException do
  it 'incorrect syntax' do
    expect do
      session = driver.session
      driver.session.run('CRETE ()').to_a
    ensure
      session&.close
    end.to raise_error described_class
  end
end
