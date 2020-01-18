# frozen_string_literal: true

RSpec.describe 'LoggingSpec' do
  let(:logger) { ActiveSupport::Logger.new(IO::NULL, level: ::Logger::DEBUG) }

  it 'log records debug and trace info' do
    expect(logger).to receive(:add).at_least(:twice)
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token, logger: logger, encryption: false) do |driver|
      driver.session do |session|
        session.run("CREATE (a {name:'Cat'})")
      end
    end
  end
end
