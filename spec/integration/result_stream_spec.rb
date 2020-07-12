# frozen_string_literal: true

RSpec.describe 'ResultStream' do
  it 'allows iterating over result stream' do
    driver.session do |session|
      res = session.run('UNWIND [1,2,3,4] AS a RETURN a')
      idx = 0
      expect(res.next['a']).to eq idx += 1 while res.has_next?
    end
  end

  it 'has field names in result' do
    driver.session do |session|
      res = session.run("CREATE (n:TestNode {name:'test'}) RETURN n")
      expect(res.keys).to eq [:n]
      expect(res.single).not_to be_nil
      expect(res.keys).to eq [:n]
    end
  end

  it 'gives helpful failure message when access non existing field' do
    driver.session do |session|
      res = session.run('CREATE (n:Person {name: $name}) RETURN n', name: 'Tom Hanks')
      single = res.single
      expect(single[:m]).to be_nil
    end
  end

  it 'gives helpful failure message when access non existing property on node' do
    driver.session do |session|
      res = session.run('CREATE (n:Person {name: $name}) RETURN n', name: 'Tom Hanks')
      record = res.single
      expect(record[:n][:age]).to be_nil
    end
  end

  it 'does not return null keys on empty result' do
    driver.session do |session|
      res = session.run('CREATE (n:Person {name: $name})', name: 'Tom Hanks')
      expect(res.keys).not_to be_nil
      expect(res.keys).to be_empty
    end
  end

  it 'is able to reuse session after failure' do
    driver.session do |session|
      res1 = session.run('INVALID')
      expect(&res1.method(:consume)).to raise_error Neo4j::Driver::Exceptions::ClientException
      res2 = session.run('RETURN 1')
      expect(res2).to have_next
      expect(res2.keys).to eq [:'1']
      record = res2.next
      expect(record.values).to eq [1]
      expect(record[0]).to eq 1
      expect(record['1']).to eq 1
    end
  end

  it 'is able to access summary after failure' do
    driver.session do |session|
      res = session.run('INVALID')
      res.consume
    rescue Neo4j::Driver::Exceptions::ClientException
      # ignore
    ensure
      summary = res.consume
      expect(summary).not_to be_nil
      expect(summary.server.address).to eq uri.split('//').last
      expect(summary.counters.nodes_created).to eq 0
    end
  end

  it 'is able to access summary after transaction failure' do
    driver.session do |session|
      result = nil
      expect do
        session.begin_transaction do |tx|
          result = tx.run('UNWIND [1,2,0] AS x RETURN 10/x')
          tx.commit
        end
      end.to raise_error Neo4j::Driver::Exceptions::ClientException

      expect(result).not_to be_nil
      expect(result.consume.counters.nodes_created).to eq 0
    end
  end

  it 'has no elements after failure' do
    driver.session do |session|
      result = session.run('INVALID')
      expect(&result.method(:has_next?)).to raise_error Neo4j::Driver::Exceptions::ClientException
      expect(result).not_to have_next
    end
  end

  it 'is an empty list after failure' do
    driver.session do |session|
      result = session.run('UNWIND (0, 1) as i RETURN 10 / i')
      expect(&result.method(:to_a)).to raise_error Neo4j::Driver::Exceptions::ClientException
      expect(result.to_a).to be_empty
    end
  end

  it 'converts empty statement result to stream' do
    driver.session do |session|
      count = session.run('MATCH (n:WrongLabel) RETURN n').count
      expect(count).to eq 0
      result = session.run('MATCH (n:OtherWrongLabel) RETURN n')
      expect(result).not_to be_any
    end
  end

  it 'converts statement result to stream' do
    driver.session do |session|
      received_list = session.run('UNWIND range(1, 10) AS x RETURN x').map { |record| record[0] }
      expect(received_list).to eq((1..10).to_a)
    end
  end

  it 'converts immediatelly failing statement result to stream' do
    driver.session do |session|
      seen = []
      expect { session.run('RETURN 10 / 0').each { |record| seen << record[0] } }
        .to raise_error Neo4j::Driver::Exceptions::ClientException, /\/ by zero/
      expect(seen).to be_empty
    end
  end

  it 'converts eventually failing statement result to stream' do
    driver.session do |session|
      seen = []
      expect { session.run('UNWIND range(5, 0, -1) AS x RETURN x / x').each { |record| seen << record[0] } }
        .to raise_error Neo4j::Driver::Exceptions::ClientException, /\/ by zero/

      # stream should manage to consume all elements except the last one, which produces an error
      expect(seen).to eq([1] * 5)
    end
  end

  it 'empties result when converted to stream' do
    driver.session do |session|
      result = session.run('UNWIND range(1, 10) AS x RETURN x')
      expect(result).to have_next
      expect(result.next.first).to eq 1
      expect(result).to have_next
      expect(result.next.first).to eq 2
      expect(result.map(&:first)).to eq((3..10).to_a)
      expect(result).not_to have_next
      expect(&result.method(:next)).to raise_error Neo4j::Driver::Exceptions::NoSuchRecordException
      expect(result.to_a).to be_empty
      expect(result.count).to eq 0
    end
  end

  it 'comsumes large result as parallel stream' do
    driver.session do |session|
      received_list = Parallel.map(session.run("UNWIND range(1, 200000) AS x RETURN 'value-' + x"), &:first)
      expect(received_list).to eq Array.new(200_000) { |i| "value-#{i + 1}" }
    end
  end
end
