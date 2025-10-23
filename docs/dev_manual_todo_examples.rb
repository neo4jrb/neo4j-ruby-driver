######################################
# Query the database
######################################

result = driver.execute_query(
  'MATCH (p:Person {age: $age}) RETURN p.name AS name',
  nil, # auth_token - positional argument can't be omitted when config is provided
  { database: 'neo4j' }, # config - default value may be omitted
  age: 42
)

# To access records after
records = result.records
records.each do |r|
  puts r
end

# Summary information
summary = result.summary
puts "The query #{summary.query.text} returned #{records.size} records in #{summary.result_available_after} ms."

######################################
# Write to the database
######################################

# Create two nodes and a relationship
result = driver.execute_query(
  'CREATE (a:Person {name: $name})
   CREATE (b:Person {name: $friend})
   CREATE (a)-[:KNOWS]->(b)',
  name: 'Alice',
  friend: 'David'
)

summary = result.summary
puts "Created #{summary.counters.nodes_created} records in #{summary.result_available_after} ms."

######################################
# Read from the database
######################################

# Retrieve all Person nodes who know other Persons
result = driver.execute_query(
  'MATCH (p:Person)-[:KNOWS]->(:Person)
   RETURN p.name AS name'
)

records = result.records
records.each do |r|
  puts r
end

summary = result.summary
puts "The query #{summary.query} returned #{records.size} records in #{summary.result_available_after} ms."

######################################
# Update the database
######################################

# Update node Alice to add an age property
result = driver.execute_query(
  'MATCH (p:Person {name: $name})
   SET p.age = $age',
  name: 'Alice',
  age: 42
)

summary = result.summary
puts "Query updated the database?"
puts summary.counters.contains_updates?

# Create a relationship :KNOWS between Alice and Bob
result = driver.execute_query(
  'MATCH (alice:Person {name: $name})
   MATCH (bob:Person {name: $friend})
   CREATE (alice)-[:KNOWS]->(bob)',
  name: 'Alice',
  friend: 'Bob'
)

summary = result.summary
puts 'Query updated the database?'
puts summary.counters.contains_updates?

######################################
# Delete from the database
######################################

# Remove the Alice node and all its relationships
result = driver.execute_query(
  'MATCH (p:Person {name: $name})
   DETACH DELETE p',
  name: 'Alice'
)

summary = result.summary
puts "Query updated the database?"
puts summary.counters.contains_updates?

######################################
# Query configuration
######################################

# Database selection
driver.execute_query(
  'MATCH (p:Person) RETURN p.name',
  nil,
  { database: 'neo4j' },
  age: 42
)

# Run queries as a different user
auth_token = Neo4j::Driver::AuthTokens.basic('another_user', 'password')
driver.execute_query(
  'MATCH (p:Person) RETURN p.name',
  auth_token,
  age: 42
)

######################################
# Summary
######################################

# Retrieve the execution summary
result = driver.execute_query(
  "UNWIND ['Alice', 'Bob'] AS name
   MERGE (p:Person {name: name})"
)

puts result.summary

# Query counters
result = driver.execute_query(
  "MERGE (p:Person {name: $name})
   MERGE (p)-[:KNOWS]->(:Person {name: $friend})",
  name: 'Mark',
  friend: 'Bob'
)
query_counters = result.summary.counters
puts query_counters

# Query execution plan
result = driver.execute_query(
  'EXPLAIN MATCH (p {name: $name}) RETURN p',
  name: 'Alice'
)
query_plan = result.summary.plan.arguments['string-representation']
puts query_plan

# Notifications with Neo4j status codes
result = driver.execute_query(
  "MATCH p=shortestPath((:Person {name: $start})-[*]->(:Person {name: $end}))
   RETURN p",
  start: 'Alice',
  end: 'Bob'
)
notifications = result.summary.notifications
puts notifications

# Notifications with GQL status codes
result = driver.execute_query(
  "MATCH p=shortestPath((:Person {name: $start})-[*]->(:Person {name: $end}))
   RETURN p",
  start: 'Alice',
  end: 'Bob'
)
statuses = result.summary.gql_status_objects
puts statuses

# Filter notifications
# Allow only WARNING notifications, but not of HINT or GENERIC classifications
driver = Neo4j::Driver::GraphDatabase.driver(
  'bolt://localhost:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password'),
  notification_config: {
    minimum_severity: :warning, # use :off to disable entirely
    disabled_categories: [:hint, :generic]
  }
)