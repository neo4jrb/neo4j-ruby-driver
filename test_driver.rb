#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/neo4j/driver'

# Simple test script to validate the driver
# Make sure you have a Neo4j instance running at bolt://localhost:7687

uri = ENV.fetch('NEO4J_URI', 'bolt://localhost:7687')
user = ENV.fetch('NEO4J_USER', 'neo4j')
password = ENV.fetch('NEO4J_PASS', 'password')

puts "Testing Neo4j Ruby Driver 2..."
puts "Connecting to #{uri}..."

begin
  Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password)) do |driver|
    puts "✓ Driver created successfully"

    # Test verify connectivity
    driver.verify_connectivity
    puts "✓ Connectivity verified"

    # Test simple query
    driver.session do |session|
      result = session.run('RETURN 1 AS num, "Hello" AS greeting')
      record = result.single

      puts "✓ Query executed successfully"
      puts "  Result: num=#{record['num']}, greeting=#{record['greeting']}"

      # Test parameters
      result2 = session.run('RETURN $x * 2 AS doubled', x: 21)
      record2 = result2.single
      puts "✓ Parameterized query: #{record2['doubled']}"

      # Test transaction
      session.begin_transaction do |tx|
        tx.run('CREATE (n:TestNode {value: $val}) RETURN n', val: 'test_value').consume
        tx.commit
      end
      puts "✓ Transaction committed"

      # Verify the node was created
      result3 = session.run('MATCH (n:TestNode {value: "test_value"}) RETURN count(n) AS count')
      count = result3.single['count']
      puts "✓ Node verified: count=#{count}"

      # Clean up
      session.run('MATCH (n:TestNode) DETACH DELETE n').consume
      puts "✓ Cleanup completed"
    end
  end

  puts "\n✅ All tests passed!"
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(10)
  exit 1
end
