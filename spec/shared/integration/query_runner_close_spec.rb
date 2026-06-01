# frozen_string_literal: true

# Ported from neo4j-java-driver QueryRunnerCloseIT.java.
#
# After a Result is consumed or its session is closed:
#   - record-access methods (has_next?, next, to_a, single, peek, each)
#     must raise ResultConsumedException;
#   - non-record methods (consume, keys) keep working idempotently.
#
# session_spec already has minimal 'Does Not Allow Accessing Records'
# coverage that exercises only to_a; this spec adds the full surface.
RSpec.describe 'Result access after consume / session close' do
  describe 'after consume' do
    it 'raises ResultConsumedException for every record-access method' do
      driver.session do |session|
        result = session.run('UNWIND [1,2] AS a RETURN a')
        result.consume

        expect { result.has_next? }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
        expect { result.next       }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
        expect { result.to_a       }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
        expect { result.single     }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
        expect { result.peek       }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
        expect { result.each {}    }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
      end
    end

    it 'still allows consume and keys (idempotent / cached)' do
      driver.session do |session|
        result = session.run('UNWIND [1,2] AS a RETURN a')
        keys = result.keys
        summary = result.consume

        # A second consume returns the same summary; keys remain available.
        expect(result.consume).to eq summary
        expect(result.keys).to eq keys
      end
    end
  end

  describe 'after session close' do
    it 'raises ResultConsumedException on record-access methods' do
      session = driver.session
      result = session.run('UNWIND [1,2] AS a RETURN a')
      session.close

      expect { result.has_next? }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
      expect { result.to_a      }.to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
    end

    it 'still allows summary and keys' do
      session = driver.session
      result = session.run('UNWIND [1,2] AS a RETURN a')
      keys = result.keys
      summary = result.consume
      session.close

      expect(result.consume).to eq summary
      expect(result.keys).to eq keys
    end
  end
end
