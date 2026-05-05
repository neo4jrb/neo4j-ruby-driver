# Neo4j Ruby Driver

## Essential References

### Specifications
- **Bolt Protocol**: https://neo4j.com/docs/bolt/current/
- **PackStream**: https://neo4j.com/docs/bolt/current/packstream/

### Official Drivers (for comparison)
- **Java** (reference impl): https://github.com/neo4j/neo4j-java-driver and https://github.com/neo4j/bolt-connection-java
- **Python**: https://github.com/neo4j/neo4j-python-driver
- **JavaScript**: https://github.com/neo4j/neo4j-javascript-driver
- **Go**: https://github.com/neo4j/neo4j-go-driver

When in doubt, check the Java driver - it's the most comprehensive reference implementation.

Pure Ruby implementation of the Neo4j Bolt protocol (no JRuby dependency).
When in doubt about driver semantics, the Java driver is the reference:
https://github.com/neo4j/neo4j-java-driver

See `DEVELOPMENT.md` for dev-loop commands and `DECISIONS.md` for the
dated log of architectural choices.

## Layout

Dev tree is split into `lib/{shared,mri,jruby}/`. The published gem is
flattened to `lib/` via a staged build (Pattern 1 — see JRUBY.md).

```
lib/shared/neo4j/driver.rb        Gem entry (Zeitwerk setup; pushes shared + impl roots)
lib/mri/neo4j/driver/             MRI implementation
  bolt/                           Bolt protocol: connection, messages
  packstream/                     Binary serialization: packer/unpacker
  types/                          Neo4j types (Node, Relationship, Path, temporal, Point, Duration)
  exceptions/                     Exception hierarchy, one class per file
  session.rb                      Session + auto-commit
  transaction.rb                  Explicit transactions
  result.rb                       Streaming result
  record.rb / summary.rb
lib/jruby/neo4j/driver/           JRuby implementation (currently empty)
```

## API conventions

- Node labels, relationship types, and field keys → symbols (converted at hydration).
- Record property keys stored as strings; accessible via string *or* symbol.
- `session.run(query, parameters = {}, config = {})` — explicit split. Same key allowed in both hashes.
- Timeouts are seconds (or `ActiveSupport::Duration`); converted to ms for the Bolt wire internally.
- Bookmarks are **replaced** on each successful commit, not accumulated. `session.last_bookmarks` returns a Set of 0 or 1. Rollback, failure, and auto-commit queries do not update them.

### Transaction shapes

1. `session.run` — auto-commit, no BEGIN.
2. `session.execute_read/write { |tx| … }` — managed. Auto-commits on clean exit; retries transient failures with exponential backoff (1s, 2s, 4s…) up to `max_transaction_retry_time`.
3. `session.begin_transaction { |tx| … }` — explicit. **Default-rollback** on clean exit; user must call `tx.commit`.

## Bolt protocol: LOCAL seconds encoding

Signatures 0x46 (DateTime with offset) and 0x66 (DateTime with zone name) encode
`epoch_seconds` as **wall-clock time treated as if it were UTC**, not the true
UTC instant. Pack adds `utc_offset`; hydrate subtracts it. For 0x66 specifically,
use `tz.tzinfo.local_to_utc(wall_clock)` so the zone's actual offset at that
instant is applied — `2 * tz.utc_offset` only happens to work in summer because
standard offset doubled equals the DST offset.

## Style

- Trust callers. No defensive `.dup`, `.freeze`, or type guards unless the task requires it.
- Ruby 3.4+ idioms: hash value omission (`metadata:`), method references (`&Bookmark.method(:new)`), `it` block parameter (`hash.transform_values { it.foo }`), `&.then { ... }` pipelines over guard-and-statement, `Array()`, `.compact` over nil-skipping conditionals.
- Polymorphism over `is_a?` / `case/when` on type. Tell, don't ask.
- Explicit over clever. Separate parameters from config rather than extracting from merged kwargs.
- Extract duplication at the third occurrence, not the second.
- Zeitwerk one-class-per-file. Namespace modules are autovivified from directory names — do **not** create `<namespace>.rb` stubs that just declare `module Foo; end`.
- All stdlib/gem `require`s live in `lib/neo4j/driver.rb`. Never scatter them in internal files.
- Error messages: helpful and contextual (`"Transaction is already closed"`, not `"Invalid state"`). Map to Neo4j error codes where applicable.

## Testing

```bash
TEST_NEO4J_URL=bolt://localhost:7687
TEST_NEO4J_USER=neo4j
TEST_NEO4J_PASS=password
bundle exec rspec
```

- `spec/shared/integration/` — end-to-end against a running Neo4j instance (run on both impls).
- `spec/shared/neo4j/driver/` — unit tests of the public API (run on both impls).
- `spec/mri/` and `spec/jruby/` — impl-specific tests.

## Testkit 
https://github.com/neo4j-drivers/testkit is the shared integration/conformance test suite for Neo4j drivers. The `testkit-backend/` directory contains the Ruby backend that testkit's Python test runner talks to over a TCP socket using a line-delimited JSON protocol. The `testkit/` directory one level up holds the Python orchestration scripts that testkit's Docker runner calls.