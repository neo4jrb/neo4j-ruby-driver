# Neo4j Ruby Driver

This repository contains 2 implementation of a Neo4j driver for Ruby:

- based on official Java implementation. It provides a thin wrapper over the Java driver (only on jruby).
- pure Ruby implementation. Available on all Ruby versions >= 3.1.

Network communication is handled using [Bolt Protocol](https://7687.org/).

<details>
<summary>Table of Contents</summary>

* [Getting started](#getting-started)
    * [Installation](#installation)
    * [Getting a Neo4j instance](#getting-a-neo4j-instance)
    * [Quick start example](#quick-start-example)
* [Server Compatibility](#server-compatibility)
* [Usage](#usage)
    * [Connecting to a database](#connecting-to-a-database)
        * [URI schemes](#uri-schemes)
        * [Authentication](#authentication)
        * [Configuration](#configuration)
        * [Connectivity check](#connectivity-check)
    * [Sessions & transactions](#sessions--transactions)
        * [Session](#session)
        * [Auto-commit transactions](#auto-commit-transactions)
        * [Explicit transactions](#explicit-transactions)
        * [Read transactions](#read-transactions)
        * [Write transactions](#write-transactions)
    * [Working with results](#working-with-results)
        * [Accessing Node and Relationship data](#accessing-node-and-relationship-data)
        * [Working with Paths](#working-with-paths)
        * [Working with temporal types](#working-with-temporal-types)
    * [Type mapping](#type-mapping)
    * [Advanced](#advanced)
        * [Connection pooling](#connection-pooling)
        * [Logging](#logging)
* [For Driver Engineers](#for-driver-engineers)
    * [Testing](#testing)
* [Contributing](#contributing)
* [License](#license)

</details>

## Getting started

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'neo4j-ruby-driver'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install neo4j-ruby-driver
```

### Getting a Neo4j instance

You need a running Neo4j database in order to use the driver with it. The easiest way to spin up a **local instance** is
through a Docker container.

The command below runs the latest Neo4j version in Docker, setting the admin username and password to `neo4j` and
`password` respectively:

```bash
docker run \
        -p7474:7474 \                    # forward port 7474 (HTTP)
        -p7687:7687 \                    # forward port 7687 (Bolt)
        -d \                             # run in background
        -e NEO4J_AUTH=neo4j/password \   # set login credentials
        neo4j:latest
```

### Quick start example

```ruby
require 'neo4j/driver'

Neo4j::Driver::GraphDatabase.driver(
  'bolt://localhost:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password')
) do |driver|
  driver.session(database: 'neo4j') do |session|
    query_result = session.run('RETURN 2+2 AS value')
    puts "2+2 equals #{query_result.single['value']}"

    # consume gives the execution summary
    create_result = session.run('CREATE (n)').consume
    puts "Nodes created: #{create_result.counters.nodes_created}"
  end
end
```

## Server Compatibility

The compatibility with Neo4j Server versions is documented in
the [Neo4j Knowledge Base](https://neo4j.com/developer/kb/neo4j-supported-versions/).

## Usage

The API is to highest possible degree consistent with the official Java driver. Please refer to
the [Neo4j Java Driver Manual](https://neo4j.com/docs/java-manual/current/), [examples in Ruby](https://github.com/neo4jrb/neo4j-ruby-driver/blob/master/docs/dev_manual_examples.rb),
and code snippets below to understand how to use it.
[Neo4j Java Driver API Docs](https://neo4j.com/docs/api/java-driver/current/) can be helpful as well.

### Connecting to a database

#### URI schemes

The driver supports the following URI schemes:

| URI Scheme     | Description                                                                     |
|----------------|---------------------------------------------------------------------------------|
| `neo4j://`     | Connect using routing to a cluster/causal cluster.                              |
| `neo4j+s://`   | Same as `neo4j://` but with full TLS encryption.                                |
| `neo4j+ssc://` | Same as `neo4j://` but with full TLS encryption, without hostname verification. |
| `bolt://`      | Connect directly to a server using the Bolt protocol.                           |
| `bolt+s://`    | Same as `bolt://` but with full TLS encryption.                                 |
| `bolt+ssc://`  | Same as `bolt://` but with full TLS encryption, without hostname verification.  |

Example:

```ruby
# Connect to a single instance
driver = Neo4j::Driver::GraphDatabase.driver(
  'bolt://localhost:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password')
)

# Connect to a cluster
driver = Neo4j::Driver::GraphDatabase.driver(
  'neo4j://graph.example.com:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password')
)
```

#### Authentication

The driver provides multiple authentication methods:

```ruby
# Basic authentication
auth = Neo4j::Driver::AuthTokens.basic('neo4j', 'password')

# With realm specification
auth = Neo4j::Driver::AuthTokens.basic('neo4j', 'password', 'realm')

# Kerberos authentication
auth = Neo4j::Driver::AuthTokens.kerberos('ticket')

# Bearer authentication
auth = Neo4j::Driver::AuthTokens.bearer('token')

# Custom authentication
auth = Neo4j::Driver::AuthTokens.custom('principal', 'credentials', 'realm', 'scheme')

# No authentication
auth = Neo4j::Driver::AuthTokens.none
```

#### Configuration

You can configure the driver with additional options:

```ruby
config = {
  connection_timeout: 15.seconds,
  connection_acquisition_timeout: 1.minute,
  max_transaction_retry_time: 30.seconds,
  encryption: true,
  trust_strategy: :trust_all_certificates
}

driver = Neo4j::Driver::GraphDatabase.driver(
  'neo4j://localhost:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password'),
  **config
)
```

#### Connectivity check

```ruby
if driver.verify_connectivity
  puts "Driver is connected to the database"
else
  puts "Driver cannot connect to the database"
end
```

### Sessions & transactions

The driver provides sessions to interact with the database and to execute queries.

#### Session

Sessions are lightweight and disposable database connections. Always close your sessions when done:

```ruby
session = driver.session(database: 'neo4j')
begin
  session.run('MATCH (n) RETURN n LIMIT 10')
ensure
  session.close
end
```

Or use a block that automatically closes the session:

```ruby
driver.session(database: 'neo4j') do |session|
  session.run('MATCH (n) RETURN n LIMIT 10')
end
```

Session options:

```ruby
# Default database
session = driver.session

# Specific database
session = driver.session(database: 'neo4j')

# With access mode
session = driver.session(database: 'neo4j', default_access_mode: Neo4j::Driver::AccessMode::READ)

# With bookmarks for causal consistency
session = driver.session(
  database: 'neo4j',
  bookmarks: [Neo4j::Driver::Bookmark.from('bookmark-1')]
)
```

#### Auto-commit transactions

For simple, one-off queries, use auto-commit transactions:

```ruby
session.run('CREATE (n:Person {name: $name})', name: 'Alice')
```

#### Explicit transactions

For multiple queries that need to be executed as a unit, use explicit transactions:

```ruby
tx = session.begin_transaction
begin
  tx.run('CREATE (n:Person {name: $name})', name: 'Alice')
  tx.run('CREATE (n:Person {name: $name})', name: 'Bob')
  tx.commit
rescue
  tx.rollback
  raise
end
```

#### Read transactions

Specifically for read operations:

```ruby
result = session.read_transaction do |tx|
  tx.run('MATCH (n:Person) RETURN n.name').map { |record| record['n.name'] }
end
puts result
```

#### Write transactions

Specifically for write operations:

```ruby
session.write_transaction do |tx|
  tx.run('CREATE (n:Person {name: $name})', name: 'Charlie')
end
```

### Working with results

```ruby
result = session.run('MATCH (n:Person) RETURN n.name AS name, n.age AS age')

# Process results
result.each do |record|
  puts "#{record['name']} is #{record['age']} years old"
end

# Check if there are more results
puts "Has more results: #{result.has_next?}"

# Get a single record
single = result.single
puts single['name'] if single

# Get keys available in the result
puts "Keys: #{result.keys}"

# Access by field index
result.each do |record|
  puts "First field: #{record[0]}"
end

# Convert to array
records = result.to_a
```

#### Accessing Node and Relationship data

Working with graph entities:

```ruby
result = session.run('MATCH (p:Person)-[r:KNOWS]->(friend) RETURN p, r, friend')

result.each do |record|
  # Working with nodes
  person = record['p']
  puts "Node ID: #{person.id}"
  puts "Labels: #{person.labels.join(', ')}"
  puts "Properties: #{person.properties}"
  puts "Name property: #{person.properties['name']}"

  # Working with relationships
  relationship = record['r']
  puts "Relationship ID: #{relationship.id}"
  puts "Type: #{relationship.type}"
  puts "Properties: #{relationship.properties}"

  # Start and end nodes of the relationship
  puts "Relationship: #{relationship.start_node_id} -> #{relationship.end_node_id}"
end
```

#### Working with Paths

Processing paths returned from Cypher:

```ruby
result = session.run('MATCH p = (:Person)-[:KNOWS*]->(:Person) RETURN p')

result.each do |record|
  path = record['p']

  # Get all nodes in the path
  nodes = path.nodes
  puts "Nodes in path: #{nodes.map { |n| n.properties['name'] }.join(' -> ')}"

  # Get all relationships in the path
  relationships = path.relationships
  puts "Relationship types: #{relationships.map(&:type).join(', ')}"

  # Iterate through the path segments
  path.each do |segment|
    puts "#{segment.start_node.properties['name']} -[#{segment.relationship.type}]-> #{segment.end_node.properties['name']}"
  end
end
```

#### Working with temporal types

Creating a node with properties of temporal types:

```ruby
session.run(
  'CREATE (e:Event {datetime: $datetime, duration: $duration})',
  datetime: DateTime.new(2025, 5, 5, 5, 55, 55), duration: 1.hour
)
```

Querying temporal values:

```ruby
session.run('MATCH (e:Event) LIMIT 1 RETURN e.datetime, e.duration').single.to_h
# => {"e.datetime": 2025-05-05 05:55:55 +0000, "e.duration": 3600 seconds}
```

### Type mapping

The Neo4j Ruby Driver maps Cypher types to Ruby types:

| Cypher Type    | Ruby Type                                     |
|----------------|-----------------------------------------------|
| null           | nil                                           |
| List           | Enumerable                                    |
| Map            | Hash (symbolized keys)                        |
| Boolean        | TrueClass/FalseClass                          |
| Integer        | Integer/String[^1]                            |
| Float          | Float                                         |
| String         | String/Symbol[^2] (encoding: UTF-8)           |
| ByteArray      | String (encoding: BINARY)                     |
| Date           | Date                                          |
| Zoned Time     | Neo4j::Driver::Types::OffsetTime              |
| Local Time     | Neo4j::Driver::Types::LocalTime               |
| Zoned DateTime | Time/ActiveSupport::TimeWithZone/DateTime[^3] |
| Local DateTime | Neo4j::Driver::Types::LocalDateTime           |
| Duration       | ActiveSupport::Duration                       |
| Point          | Neo4j::Driver::Types::Point                   |
| Node           | Neo4j::Driver::Types::Node                    |
| Relationship   | Neo4j::Driver::Types::Relationship            |
| Path           | Neo4j::Driver::Types::Path                    |

[^1]: An Integer smaller than -2 ** 63 or larger than 2 ** 63 will always be implicitly converted to String
[^2]: A Symbol passed as a parameter will always be implicitly converted to String. All Strings other than BINARY
encoded are converted to UTF-8 when stored in Neo4j
[^3]: A Ruby DateTime passed as a parameter will always be implicitly converted to Time

### Advanced

#### Connection pooling

The driver handles connection pooling automatically. Configure the connection pool:

```ruby
config = {
  max_connection_pool_size: 100,
  max_connection_lifetime: 1.hour
}

driver = Neo4j::Driver::GraphDatabase.driver('neo4j://localhost:7687', auth, **config)
```

#### Logging

Configure logging for the driver:

```ruby
config = {
  logger: Logger.new(STDOUT).tap { |log| log.level = Logger::DEBUG }
}

driver = Neo4j::Driver::GraphDatabase.driver('neo4j://localhost:7687', auth, **config)
```

## For Driver Engineers

This gem includes 2 different implementations: a Java driver wrapper and a pure Ruby driver, so you will have to run
this command every time you switch the Ruby engine:

```bash
bin/setup
```

### Testing

There are two sets of tests for the driver. To run the specs placed in this repository, use a normal rspec command:

```bash
rspec spec
```

To run the [Testkit](https://github.com/neo4j-drivers/testkit) that is used to test all Neo4j driver implementations,
use the following:

```bash
git clone git@github.com:neo4j-drivers/testkit.git
cd testkit
export TEST_DRIVER_NAME=ruby
export TEST_DRIVER_REPO=`realpath ../neo4j-ruby-driver`
export TEST_NEO4J_PASS=password
python3 main.py --tests UNIT_TESTS --configs 4.3-enterprise
```

Please refer to the [Testkit](https://github.com/neo4j-drivers/testkit) documentation to learn more about its features.

## Contributing

Suggestions, improvements, bug reports and pull requests are welcome on GitHub
at https://github.com/neo4jrb/neo4j-ruby-driver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
