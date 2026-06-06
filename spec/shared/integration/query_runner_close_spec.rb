# frozen_string_literal: true

# Ported from neo4j-java-driver QueryRunnerCloseIT.java (sync tests).
#
# After a Result is consumed or its session is closed:
#   - record-access methods (has_next?, next, to_a, single, peek, each)
#     must raise ResultConsumedException;
#   - non-record methods (consume, keys) keep working idempotently —
#     consume returns the same summary, keys stay available.
RSpec.describe 'Result access after consume / session close' do
  def record_access_methods(result)
    [-> { result.has_next? }, -> { result.next }, -> { result.to_a },
     -> { result.single }, -> { result.peek }, -> { result.each {} }]
  end

  it 'errors to access records after consume' do
    driver.session do |session|
      result = session.run('UNWIND [1,2] AS a RETURN a')
      result.consume

      record_access_methods(result).each do |access|
        expect(&access).to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
      end
    end
  end

  it 'errors to access records after close' do
    session = driver.session
    result = session.run('UNWIND [1,2] AS a RETURN a')
    session.close

    record_access_methods(result).each do |access|
      expect(&access).to raise_error(Neo4j::Driver::Exceptions::ResultConsumedException)
    end
  end

  it 'allows consume and keys after consume' do
    driver.session do |session|
      result = session.run('UNWIND [1,2] AS a RETURN a')
      keys = result.keys
      summary = result.consume

      # consume returns the same summary; keys remain available.
      expect(result.consume).to eq summary
      expect(result.keys).to eq keys
    end
  end

  it 'allows summary and keys after close' do
    session = driver.session
    result = session.run('UNWIND [1,2] AS a RETURN a')
    keys = result.keys
    summary = result.consume # consume yields the summary
    session.close

    expect(result.consume).to eq summary
    expect(result.keys).to eq keys
  end
end
