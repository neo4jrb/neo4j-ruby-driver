# Neo4j Ruby Driver

A driver for [Neo4j](https://neo4j.com) that speaks the
[Bolt protocol](https://neo4j.com/docs/bolt/current/), with **two
implementations behind one public Ruby API**:

- **MRI** (CRuby) — a pure-Ruby implementation of the Bolt protocol and
  PackStream, with no Java dependency.
- **JRuby** — a thin wrapper over the official
  [neo4j-java-driver](https://github.com/neo4j/neo4j-java-driver), whose jars
  are managed by [jar-dependencies](https://github.com/mkristian/jar-dependencies).

Bundler installs the implementation matching your platform automatically, and
your code is identical either way. The gem version tracks the Java-driver
version it targets (e.g. `6.2.x`).

## Features

- **Bolt 3.0 – 6.1** with handshake-manifest version negotiation
- **Complete type system**: Node, Relationship, Path, temporal types, spatial
  Point, Duration, UUID, and a forward-compatible `UnsupportedType`
- **Transactions**: auto-commit, explicit (default-rollback), and managed
  read/write with automatic retry
- **Sessions & causal consistency** via bookmarks
- **Authentication**: basic, bearer, Kerberos, custom, and managed auth-token
  managers (with re-auth); per-session and per-`execute_query` auth
- **Cluster routing** with home-database resolution and caching
- **Security**: TLS 1.2/1.3, `bolt+s`/`bolt+ssc` schemes, and mutual-TLS client
  certificates
- **Notifications config, GQL status objects, query telemetry**, connection
  pooling, and a range of wire optimisations
- Verified against the shared driver
  [testkit](https://github.com/neo4j-drivers/testkit) conformance suite on both
  implementations

## Installation

```ruby
# Gemfile
gem 'neo4j-ruby-driver'
```

```bash
bundle install
```

## Usage

### Basic connection

```ruby
require 'neo4j/driver'

Neo4j::Driver::GraphDatabase.driver(
  'bolt://localhost:7687',
  Neo4j::Driver::AuthTokens.basic('neo4j', 'password')
) do |driver|
  driver.session do |session|
    result = session.run('RETURN 1 AS num')
    puts result.single[:num] # => 1
  end
end
```

Use a `bolt://` URL for a single instance, `neo4j://` for a routed (cluster)
connection, and the `+s`/`+ssc` variants for TLS.

### Parameterized queries

```ruby
driver.session do |session|
  node = session.run(
    'CREATE (n:Person {name: $name, age: $age}) RETURN n',
    name: 'Alice', age: 30
  ).single[:n]

  puts node[:name] # => "Alice"
end
```

`session.run(query, parameters = {}, config = {})` keeps parameters and config
as separate explicit hashes.

### Explicit transactions

Explicit transactions are **default-rollback** — you must call `tx.commit`.

```ruby
driver.session do |session|
  session.begin_transaction do |tx|
    tx.run('CREATE (:Person {name: "Bob"})')
    tx.run('CREATE (:Person {name: "Charlie"})')
    tx.commit
  end
end
```

### Managed transaction functions

Auto-commit on clean exit; transient failures are retried with exponential
backoff.

```ruby
driver.session do |session|
  session.execute_write do |tx|
    tx.run('CREATE (n:Person {name: "Diana"}) RETURN n').single
  end

  people = session.execute_read do |tx|
    tx.run('MATCH (p:Person) RETURN p.name AS name').collect { |r| r[:name] }
  end
end
```

### Working with results

```ruby
result = session.run('MATCH (p:Person) RETURN p.name AS name, p.age AS age')

result.each { |record| puts "#{record[:name]} is #{record[:age]}" }

record = result.single  # exactly one row
name   = record[:name]  # by key (string or symbol)
age    = record[1]      # or by index

records = result.to_a
```

Node labels and relationship types come back as **symbols** off the entity —
`node.labels # => [:Person]`, `rel.type # => :KNOWS` — as do record columns and
map/property keys. Cypher functions that *return* strings (`labels()`, `keys()`,
`type()`) return **strings**, because their result is an ordinary value on the
wire, indistinguishable from data you returned yourself. Read the accessor for
symbols, or convert the function result with `.map(&:to_sym)`.

## Architecture

The development tree is split so shared code lives in one place and each
implementation adds only its own wire layer:

```
lib/
├── shared/   # public API + shared types, loaded by both implementations
├── mri/      # pure-Ruby Bolt protocol, PackStream, connection pool
└── jruby/    # thin wrapper over the official Java driver jars
```

The published gem is flattened to a single `lib/` for the platform via a staged
build (see `JRUBY.md`). See `CLAUDE.md` for the layout and conventions,
`DEVELOPMENT.md` for the dev loop, and `DECISIONS.md` for architectural history.

### Dependencies

- **MRI**: `tzinfo`, `zeitwerk`, `connection_pool` — no Java, no server-side
  components.
- **JRuby**: the official `neo4j-java-driver` jars, resolved by
  `jar-dependencies`; runs on a JVM (Java 17+).

## Testing

```bash
export TEST_NEO4J_URL=bolt://localhost:7687
export TEST_NEO4J_USER=neo4j
export TEST_NEO4J_PASS=password

bundle exec rspec
```

- `spec/shared/integration/` — end-to-end against a running Neo4j instance
- `spec/shared/neo4j/driver/` — public-API unit tests
- `spec/mri/`, `spec/jruby/` — implementation-specific tests

Conformance is additionally exercised through the Neo4j
[testkit](https://github.com/neo4j-drivers/testkit) suite via the Ruby backend
under `testkit-backend/`.

## Contributing

Contributions are welcome. Keep the public API flavour-agnostic (no
implementation type may leak across it), follow the conventions in `CLAUDE.md`,
and add coverage on both implementations. See `CHANGELOG.md` for recent changes.

## References

- [Bolt Protocol Specification](https://neo4j.com/docs/bolt/current/)
- [PackStream Specification](https://neo4j.com/docs/bolt/current/packstream/)
- [neo4j-java-driver](https://github.com/neo4j/neo4j-java-driver) (reference implementation)
- [Neo4j testkit](https://github.com/neo4j-drivers/testkit)

## License

Released under the [MIT License](LICENSE.txt).
