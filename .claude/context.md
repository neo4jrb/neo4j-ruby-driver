# Neo4j Ruby Driver - Project Context

> **See also**: `DEVELOPMENT.md` for day-to-day development tasks, testing, and reference links

## Essential References

### Specifications
- **Bolt Protocol**: https://neo4j.com/docs/bolt/current/
- **PackStream**: https://neo4j.com/docs/bolt/current/packstream/
- **Bolt 4.x Messages**: https://7687.org/bolt/bolt-protocol-message-specification-4.html

### Official Drivers (for comparison)
- **Java** (reference impl): https://github.com/neo4j/neo4j-java-driver
- **Python**: https://github.com/neo4j/neo4j-python-driver
- **JavaScript**: https://github.com/neo4j/neo4j-javascript-driver
- **Go**: https://github.com/neo4j/neo4j-go-driver

When in doubt, check the Java driver - it's the most comprehensive reference implementation.

## Architecture Overview

This is a pure Ruby implementation of the Neo4j Bolt protocol driver (no JRuby/Java dependencies).

### Core Components

- **`lib/neo4j/driver/bolt/`** - Bolt protocol implementation (connection, messages)
- **`lib/neo4j/driver/packstream/`** - PackStream binary serialization (packer/unpacker)
- **`lib/neo4j/driver/types.rb`** - Neo4j type system (Node, Relationship, Path, temporal types, Point, Duration)
- **`lib/neo4j/driver/session.rb`** - Session management and auto-commit transactions
- **`lib/neo4j/driver/transaction.rb`** - Explicit transaction handling
- **`lib/neo4j/driver/result.rb`** - Lazy result streaming with Record and Summary

## Key Design Decisions

### Type Conventions
- **Node labels** → symbols (converted at hydration time in bolt/connection.rb)
- **Relationship types** → symbols (converted at hydration time)
- **Result field keys** → symbols (converted when creating Result)
- **Record keys** → stored as strings internally, accessible via string or symbol

### Parameters vs Config Separation
Session#run and transaction methods use `**options` pattern:
```ruby
def run(query, parameters = {}, **options)
  timeout = options.delete(:timeout)        # Extract config
  metadata = options.delete(:metadata)      # Extract config
  parameters = (parameters || {}).merge(options)  # Merge rest into parameters
```

This allows:
- `session.run('RETURN $x', x: 1)` - keywords as parameters
- `session.run('RETURN $x', {x: 1})` - hash as parameters
- `session.run('RETURN $x', {x: 1}, timeout: 60000)` - hash + config
- `session.run('RETURN $x', {metadata: 'param'}, metadata: {config: true})` - same key in both!

### Transaction Types
1. **Auto-commit** (`session.run`) - Single RUN + PULL, no BEGIN/COMMIT
2. **Managed** (`session.execute_read/write`) - Automatic retry logic, BEGIN + RUN + COMMIT
3. **Explicit** (`session.begin_transaction`) - Manual control, user calls commit/rollback

### Bookmarks
`session.last_bookmarks` returns a **frozen duplicate** of the internal Set to prevent:
```ruby
# Without .dup.freeze, this would fail:
bookmarks = Array.new(3) { create_tx; session.last_bookmarks }
bookmarks.to_set.size # Would be 1 (same object reference 3 times!)
```

## Bolt Protocol Quirks

### PackStream Signatures (Hydration Handlers)

| Sig  | Type | Fields | Notes |
|------|------|--------|-------|
| 0x4E | Node | id, labels, props, element_id | Labels → symbols |
| 0x52 | Relationship | id, start, end, type, props, element_id | Type → symbol |
| 0x44 | Date | days_since_epoch | → Ruby Date |
| 0x46 | DateTime | epoch_sec, nanos, tz_offset | → Ruby Time |
| 0x54 | Time | nanos_since_midnight, tz_offset | → Types::Time |
| 0x64 | LocalDateTime | epoch_sec, nanos | → Types::LocalDateTime |
| 0x66 | **ZonedDateTime** | epoch_sec, nanos, tz_name | **See below** |
| 0x74 | LocalTime | nanos_since_midnight | → Types::LocalTime |

### ⚠️ CRITICAL: Signature 0x66 (ZonedDateTime with timezone name)

**The epoch_seconds field represents LOCAL time in the given timezone, NOT UTC!**

When hydrating:
```ruby
# Wrong: tz.at(epoch_seconds) gives wrong time (off by 2x offset)
# Right: tz.at(epoch_seconds - 2 * tz.utc_offset)
```

Example: `datetime("2018-04-05T12:34:00[Europe/Berlin]")`
- Neo4j sends: `epoch_seconds` for 12:34:00 (as if it were UTC)
- But it means: 12:34:00 CEST (UTC+2) = 10:34:00 UTC
- Must subtract: `2 * 7200 = 14400` seconds to get correct UTC time

### DateTime Precision
When packing Ruby Time/DateTime to signature 0x46:
```ruby
# Wrong: (value.to_f - epoch_seconds) * 1_000_000_000  # Loses precision!
# Right: value.respond_to?(:nsec) ? value.nsec : (value.subsec * 1_000_000_000).round
```

## Result Handling

### Lazy Streaming
Results stream records on-demand:
- `has_next?` fetches next RECORD message or SUCCESS (summary)
- Records are cached in `@records` after being yielded
- `consume` exhausts remaining records and returns summary
- Summary persists even after FAILURE (cached before raising exception)

### Duplicate Iteration Bug (Fixed)
Result#each was yielding records twice:
```ruby
# Wrong:
while has_next?
  block.call(self.next)  # Yields record
end
@records.each(&block)   # Yields AGAIN!

# Right: Only yield during fetch loop
```

## Temporal Types

### Comparison & Arithmetic
All temporal types implement `Comparable` and arithmetic:
- `LocalTime`: compares nanoseconds, modulo 24 hours
- `Time`: compares UTC instant (adjusts for timezone offset)
- Addition wraps at 24 hours: `Time.parse('23:00Z') + 2.hours < Time.parse('23:00Z')`

### Modulo Day Behavior
```ruby
LocalTime.new(86_400_000_000_000 + nanos) # Wraps to next day
# Result: @nanoseconds = nanos (not 86400... + nanos)
```

## Testing

### Test Organization
- `spec/integration/` - Full driver integration tests
- `spec/neo4j/driver/` - Unit tests for specific classes
- `spec/neo4j/driver/types/` - Tests for type system

### Environment Variables
```bash
TEST_NEO4J_URL=bolt://localhost:7687
TEST_NEO4J_USER=neo4j
TEST_NEO4J_PASS=password
```

### Current Status (2026-04-21)
- **388 examples total**
- **40 failures remaining** (down from 59)
- Main failing areas:
  - Session/transaction error handling edge cases
  - Parameter validation for invalid types (Node, Relationship, Path as params)
  - Some temporal type roundtrip scenarios (DateTime with zone)
  - ResultStream tests
  - Transaction rollback scenarios

## Common Patterns

### Adding New Bolt Message Type
1. Add signature constant in `bolt/message.rb`
2. Add packer logic in `packstream/packer.rb` for encoding
3. Add hydration handler in `bolt/connection.rb#register_hydration_handlers` for decoding

### Adding New Temporal Type
1. Add class to `types.rb` with `Comparable` module
2. Implement: `<=>`, `==`, `eql?`, `hash`, `+` (for arithmetic)
3. Add packing logic in `packstream/packer.rb`
4. Add hydration handler in `bolt/connection.rb#register_temporal_handlers`

## Dependencies

### Required
- Ruby standard library (Time, Date, Set)

### Optional (detected at runtime)
- **ActiveSupport** - Better timezone handling for ZonedDateTime
- **TZInfo** - Fallback for timezone handling if ActiveSupport unavailable

### Avoided
- No ActiveSupport::Duration dependency (use plain integers for seconds/milliseconds)
- No JRuby/Java driver wrapping (pure Ruby implementation)

## Anti-Patterns to Avoid

❌ Don't mutate `last_bookmarks` directly (it's frozen)
❌ Don't use `.to_f` arithmetic for nanosecond precision
❌ Don't assume signature 0x66 epoch_seconds is UTC
❌ Don't forget to convert labels/types/keys to symbols
❌ Don't use `echo` or bash for user communication (use text output)
❌ Don't add emojis unless explicitly requested
