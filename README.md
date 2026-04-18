# Neo4j Ruby Driver 2

A clean, modern implementation of the Neo4j Bolt protocol driver for Ruby, built from the ground up based on the official [Bolt Protocol Specification](https://neo4j.com/docs/bolt/current/).

## Features

- ✅ **Clean Implementation**: Built from scratch without legacy code or dependencies
- ✅ **Bolt Protocol 5.x Support**: Implements the latest Bolt protocol specifications
- ✅ **PackStream Serialization**: Full implementation of PackStream binary format
- ✅ **Complete Type System**: Support for all Neo4j types (Node, Relationship, Path, temporal types, Point, etc.)
- ✅ **Transaction Management**: Auto-commit, explicit transactions, and managed transaction functions
- ✅ **Session Management**: Full session lifecycle with bookmarks for causality
- ✅ **Connection Pooling**: Basic connection pooling for performance
- ✅ **Ruby-idiomatic API**: Follows Ruby conventions and best practices

## Architecture

The driver is organized into clean, modular layers:

```
lib/neo4j/driver/
├── packstream/           # PackStream serialization (binary protocol)
│   ├── packer.rb        # Encodes Ruby objects to PackStream
│   ├── unpacker.rb      # Decodes PackStream to Ruby objects
│   └── structure.rb     # PackStream structure type
├── bolt/                # Bolt protocol implementation
│   ├── connection.rb    # TCP connection, handshake, message framing
│   └── message.rb       # Bolt protocol messages
├── types.rb             # Neo4j types (Node, Relationship, Path, etc.)
├── exceptions.rb        # Exception hierarchy
├── auth_tokens.rb       # Authentication token builders
├── result.rb            # Result and Record classes
├── transaction.rb       # Explicit transaction
├── session.rb           # Session management
├── driver.rb            # Driver instance
└── graph_database.rb    # Main entry point
```

## Installation

Add to your Gemfile:

```ruby
gem 'neo4j-ruby-driver2', path: './neo4j-ruby-driver2'
```

Or install locally:

```bash
cd neo4j-ruby-driver2
bundle install
```

## Usage

### Basic Connection

```ruby
require 'neo4j/driver'

Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password')) do |driver|

  driver.session do |session|
    result = session.run('RETURN 1 AS num')
    puts result.single['num']  # => 1
  end
end
```

### Parameterized Queries

```ruby
driver.session do |session|
  result = session.run(
    'CREATE (n:Person {name: $name, age: $age}) RETURN n',
    name: 'Alice',
    age: 30
  )

  node = result.single['n']
  puts node[:name]  # => "Alice"
end
```

### Explicit Transactions

```ruby
driver.session do |session|
  session.begin_transaction do |tx|
    tx.run('CREATE (n:Person {name: "Bob"})')
    tx.run('CREATE (n:Person {name: "Charlie"})')
    tx.commit
  end
end
```

### Managed Transaction Functions

```ruby
driver.session do |session|
  # Automatically retries on transient failures
  result = session.execute_write do |tx|
    tx.run('CREATE (n:Person {name: "Diana"}) RETURN n').single
  end

  # Read transactions
  people = session.execute_read do |tx|
    tx.run('MATCH (p:Person) RETURN p.name AS name').to_a
  end
end
```

### Working with Results

```ruby
result = session.run('MATCH (p:Person) RETURN p.name, p.age')

# Iterate over records
result.each do |record|
  puts "#{record['p.name']} is #{record['p.age']} years old"
end

# Get single record
record = result.single
name = record['p.name']
age = record[1]  # Access by index

# Convert to array
records = result.to_a
```

## Running Tests

The driver includes the full test suite from the existing neo4j-ruby-driver:

```bash
# Start a Neo4j instance (using Docker)
docker run -d \
  --name neo4j-test \
  -p 7687:7687 \
  -p 7474:7474 \
  -e NEO4J_AUTH=neo4j/password \
  neo4j:latest

# Run the test script
bundle exec ruby test_driver.rb

# Run the full spec suite
export TEST_NEO4J_HOST=localhost
export TEST_NEO4J_PORT=7687
export TEST_NEO4J_USER=neo4j
export TEST_NEO4J_PASS=password
bundle exec rspec spec/integration/
```

## Implementation Details

### PackStream Serialization

The driver implements the complete PackStream specification:
- All marker types (Null, Boolean, Integer, Float, String, List, Map, Structure)
- Proper big-endian encoding
- Structure hydration for Neo4j types

### Bolt Protocol

- Handshake with version negotiation (Bolt 5.0-5.4)
- Chunked message framing
- All request messages: HELLO, RUN, PULL, BEGIN, COMMIT, ROLLBACK, etc.
- All response messages: SUCCESS, RECORD, FAILURE, IGNORED

### Type System

Full support for:
- Graph types: Node, Relationship, Path
- Temporal types: Date, Time, LocalTime, DateTime, LocalDateTime, Duration
- Spatial types: Point (2D and 3D)
- All primitive types with proper conversions

### Connection Management

- TCP connection with configurable timeouts
- Message queueing and pipelining
- Basic connection pooling
- Graceful connection closing

## Differences from Legacy Driver

This driver was built with modern Ruby practices:

1. **No Runtime Dependencies**: The core driver has zero runtime dependencies
2. **Clean Code**: No legacy compatibility layers or deprecated patterns
3. **Explicit Error Handling**: Clear exception hierarchy
4. **Simple Connection Model**: Straightforward TCP socket handling
5. **Ruby 3+ Features**: Uses modern Ruby idioms

## Testing Against Specifications

This driver was built to pass the existing neo4j-ruby-driver test suite located in `spec/`. The specs test:

- Connection handling (bolt and neo4j schemes)
- Session management
- Transaction semantics (auto-commit, explicit, managed)
- Result streaming
- Type conversions
- Error handling
- Concurrent access
- Retry logic

## Development Status

**Core Features Implemented:**
- ✅ PackStream serialization/deserialization
- ✅ Bolt protocol handshake and messaging
- ✅ Connection and session management
- ✅ Transaction support (all modes)
- ✅ Result streaming
- ✅ Type system
- ✅ Basic error handling

**To Be Implemented:**
- ⏳ Advanced connection pooling
- ⏳ Routing for Neo4j clusters
- ⏳ TLS/SSL support (bolt+s, bolt+ssc)
- ⏳ Reactive/async API
- ⏳ Complete retry and timeout logic
- ⏳ Logging infrastructure
- ⏳ Performance optimizations

## Contributing

This is a clean-room implementation based on the Bolt protocol specification. Contributions should maintain the clean architecture and avoid importing legacy patterns.

## References

- [Bolt Protocol Specification](https://neo4j.com/docs/bolt/current/)
- [PackStream Specification](https://neo4j.com/docs/bolt/current/packstream/)
- [Neo4j Driver API](https://neo4j.com/docs/api/javascript-driver/current/)
- [Official Python Driver](https://github.com/neo4j/neo4j-python-driver)
- [Official JavaScript Driver](https://github.com/neo4j/neo4j-javascript-driver)

## License

Apache License 2.0

## Author

Built as a clean implementation of the Neo4j Bolt protocol specification.
