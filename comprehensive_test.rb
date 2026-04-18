#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/neo4j/driver'

uri = ENV.fetch('NEO4J_URI', 'bolt://localhost:7687')
user = ENV.fetch('NEO4J_USER', 'neo4j')
password = ENV.fetch('NEO4J_PASS', 'password')

puts "=" * 60
puts "Neo4j Ruby Driver 2 - Comprehensive Test"
puts "=" * 60

test_count = 0
passed = 0
failed = 0

def test(name)
  print "Testing: #{name}... "
  yield
  puts "✓ PASS"
  return :passed
rescue => e
  puts "✗ FAIL: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
  return :failed
end

Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password)) do |driver|
  # Test 1: Basic connectivity
  test_count += 1
  result = test("Driver connectivity") do
    driver.verify_connectivity
  end
  result == :passed ? passed += 1 : failed += 1

  driver.session do |session|
    # Clean up from previous runs
    session.run('MATCH (n:TestNode) DELETE n').consume rescue nil

    # Test 2: Simple query
    test_count += 1
    result = test("Simple query (RETURN 1)") do
      r = session.run('RETURN 1 AS num')
      raise "Expected 1, got #{r.single['num']}" unless r.single['num'] == 1
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 3: Parameters
    test_count += 1
    result = test("Parameterized query") do
      r = session.run('RETURN $x + $y AS sum', x: 10, y: 32)
      raise "Expected 42, got #{r.single['sum']}" unless r.single['sum'] == 42
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 4: Create node
    test_count += 1
    result = test("Create node") do
      r = session.run('CREATE (n:TestNode {name: $name, age: $age}) RETURN n',
                      name: 'Alice', age: 30)
      node = r.single['n']
      raise "Node missing" unless node
      raise "Wrong name" unless node[:name] == 'Alice'
      raise "Wrong age" unless node[:age] == 30
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 5: Match nodes
    test_count += 1
    result = test("Match nodes") do
      session.run('CREATE (:TestNode {name: $name})', name: 'Bob').consume
      session.run('CREATE (:TestNode {name: $name})', name: 'Charlie').consume
      r = session.run('MATCH (n:TestNode) RETURN n.name AS name ORDER BY n.name')
      names = r.to_a.map { |rec| rec['name'] }
      raise "Expected 3 nodes, got #{names.size}" unless names.size == 3
      raise "Wrong names: #{names.inspect}" unless names == ['Alice', 'Bob', 'Charlie']
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 6: Relationships
    test_count += 1
    result = test("Create relationship") do
      session.run('MATCH (a:TestNode {name: "Alice"}), (b:TestNode {name: "Bob"})
                   CREATE (a)-[r:KNOWS {since: 2020}]->(b)
                   RETURN r').consume
      r = session.run('MATCH (:TestNode {name: "Alice"})-[r:KNOWS]->(:TestNode {name: "Bob"})
                       RETURN r')
      rel = r.single['r']
      raise "Relationship missing" unless rel
      raise "Wrong type" unless rel.type == 'KNOWS'
      raise "Wrong property" unless rel[:since] == 2020
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 7: Explicit transaction (commit)
    test_count += 1
    result = test("Explicit transaction (commit)") do
      session.begin_transaction do |tx|
        tx.run('CREATE (:TestNode {name: "Diana"})').consume
        tx.commit
      end
      r = session.run('MATCH (n:TestNode {name: "Diana"}) RETURN count(n) AS count')
      raise "Node not created" unless r.single['count'] == 1
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 8: Explicit transaction (rollback)
    test_count += 1
    result = test("Explicit transaction (rollback)") do
      session.begin_transaction do |tx|
        tx.run('CREATE (:TestNode {name: "Eve"})').consume
        # Don't commit - should rollback
      end
      r = session.run('MATCH (n:TestNode {name: "Eve"}) RETURN count(n) AS count')
      raise "Node should not exist" unless r.single['count'] == 0
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 9: Managed transaction (execute_write)
    test_count += 1
    result = test("Managed transaction (execute_write)") do
      result = session.execute_write do |tx|
        tx.run('CREATE (n:TestNode {name: "Frank"}) RETURN n').single['n']
      end
      raise "No result" unless result
      raise "Wrong name" unless result[:name] == 'Frank'
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 10: Managed transaction (execute_read)
    test_count += 1
    result = test("Managed transaction (execute_read)") do
      count = session.execute_read do |tx|
        tx.run('MATCH (n:TestNode) RETURN count(n) AS count').single['count']
      end
      raise "Expected at least 5 nodes, got #{count}" unless count >= 5
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 11: Multiple results
    test_count += 1
    result = test("Iterating over results") do
      r = session.run('UNWIND range(1, 5) AS x RETURN x * 2 AS doubled')
      values = []
      r.each { |record| values << record['doubled'] }
      raise "Wrong count" unless values.size == 5
      raise "Wrong values: #{values.inspect}" unless values == [2, 4, 6, 8, 10]
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 12: Result.to_a
    test_count += 1
    result = test("Result.to_a") do
      r = session.run('UNWIND ["a", "b", "c"] AS letter RETURN letter')
      arr = r.to_a
      letters = arr.map { |rec| rec['letter'] }
      raise "Wrong letters: #{letters.inspect}" unless letters == ['a', 'b', 'c']
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 13: Error handling
    test_count += 1
    result = test("Error handling (syntax error)") do
      begin
        session.run('INVALID CYPHER').consume
        raise "Should have raised an error"
      rescue Neo4j::Driver::Exceptions::ClientException => e
        raise "Wrong error message" unless e.message.include?('Syntax') || e.message.include?('syntax')
      end
    end
    result == :passed ? passed += 1 : failed += 1

    # Test 14: Empty results
    test_count += 1
    result = test("Empty result set") do
      r = session.run('MATCH (n:NonExistentLabel) RETURN n')
      raise "Should have no results" if r.has_next?
      raise "Should be none" unless r.none?
    end
    result == :passed ? passed += 1 : failed += 1

    # Clean up
    session.run('MATCH (n:TestNode) DELETE n').consume
  end
end

puts
puts "=" * 60
puts "Test Results"
puts "=" * 60
puts "Total:  #{test_count}"
puts "Passed: #{passed} (#{(passed * 100.0 / test_count).round(1)}%)"
puts "Failed: #{failed}"
puts
if failed == 0
  puts "✅ All tests passed!"
  exit 0
else
  puts "❌ Some tests failed"
  exit 1
end
