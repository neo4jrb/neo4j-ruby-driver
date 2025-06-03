# frozen_string_literal: true

RSpec.describe Neo4j::Driver, concurrency: true do

  describe '#execute_query' do
    context 'when querying the database' do
      it 'accepts query with default auth_token, config hash and parameters' do
        expect {
          driver.execute_query(
            'MATCH (p:Person {age: $age}) RETURN p.name AS name',
            nil,
            { database: 'neo4j' },
            age: 42
          )
        }.not_to raise_error
      end
    end

    context 'when writing to the database' do
      it 'accepts query with only keyword parameters' do
        expect {
          driver.execute_query(
            'CREATE (a:Person {name: $name}) CREATE (b:Person {name: $friend}) CREATE (a)-[:KNOWS]->(b)',
            name: 'Alice',
            friend: 'David'
          )
        }.not_to raise_error
      end
    end

    context 'when reading from the database' do
      it 'accepts query with no additional parameters' do
        expect {
          driver.execute_query('MATCH (p:Person)-[:KNOWS]->(:Person) RETURN p.name AS name')
        }.not_to raise_error
      end
    end

    context 'when updating the database' do
      it 'accepts update query with keyword parameters' do
        expect {
          driver.execute_query(
            'MATCH (p:Person {name: $name}) SET p.age = $age',
            name: 'Alice',
            age: 42
          )
        }.not_to raise_error
      end

      it 'accepts relationship creation with keyword parameters' do
        expect {
          driver.execute_query(
            'MATCH (alice:Person {name: $name}) MATCH (bob:Person {name: $friend}) CREATE (alice)-[:KNOWS]->(bob)',
            name: 'Alice',
            friend: 'Bob'
          )
        }.not_to raise_error
      end
    end

    context 'when deleting from the database' do
      it 'accepts delete query with keyword parameters' do
        expect {
          driver.execute_query(
            'MATCH (p:Person {name: $name}) DETACH DELETE p',
            name: 'Alice'
          )
        }.not_to raise_error
      end
    end

    context 'when using query configuration' do
      it 'accepts nil auth_token with config hash and parameters' do
        expect {
          driver.execute_query(
            'MATCH (p:Person) RETURN p.name',
            nil,
            { database: 'neo4j' },
            age: 42
          )
        }.not_to raise_error
      end

      it 'accepts auth_token with keyword parameters' do
        auth_token = Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password)

        expect {
          driver.execute_query(
            'MATCH (p:Person) RETURN p.name',
            auth_token,
            age: 42
          )
        }.not_to raise_error
      end
    end

    context 'when working with query summaries' do
      it 'accepts UNWIND query without parameters' do
        expect {
          driver.execute_query("UNWIND ['Alice', 'Bob'] AS name MERGE (p:Person {name: name})")
        }.not_to raise_error
      end

      it 'accepts MERGE query with keyword parameters' do
        expect {
          driver.execute_query(
            "MERGE (p:Person {name: $name}) MERGE (p)-[:KNOWS]->(:Person {name: $friend})",
            name: 'Mark',
            friend: 'Bob'
          )
        }.not_to raise_error
      end

      it 'accepts EXPLAIN query with keyword parameters' do
        expect {
          driver.execute_query(
            'EXPLAIN MATCH (p {name: $name}) RETURN p',
            name: 'Alice'
          )
        }.not_to raise_error
      end

      it 'accepts shortestPath query with keyword parameters' do
        expect {
          driver.execute_query(
            "MATCH p=shortestPath((:Person {name: $start})-[*]->(:Person {name: $end})) RETURN p",
            start: 'Alice',
            end: 'Bob'
          )
        }.not_to raise_error
      end
    end

    context 'parameter handling' do
      it 'handles mixed positional and keyword arguments correctly' do
        expect {
          driver.execute_query(
            'MATCH (p:Person {age: $age, name: $name}) RETURN p',
            nil,
            { database: 'neo4j' },
            age: 42,
            name: 'Alice'
          )
        }.not_to raise_error
      end

      it 'handles only keyword arguments' do
        expect {
          driver.execute_query(
            'MATCH (p:Person {name: $name}) RETURN p',
            name: 'Alice'
          )
        }.not_to raise_error
      end
    end
  end
end
