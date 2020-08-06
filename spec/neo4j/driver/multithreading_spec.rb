# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  it 'supports many concurrent thread' do
    threads = (1..10).map do |_n|
      Thread.new do
        (1..100).each do |_m|
          driver.session do |session|
            session.read_transaction {}
          end
        end
      end
    end
    threads.map(&:join)
  end
end