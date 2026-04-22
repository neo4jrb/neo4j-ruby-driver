# Development Guide

## Quick Start

### Setup
```bash
bundle install
```

### Running Tests
```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/neo4j/driver/session_spec.rb

# Specific test
bundle exec rspec spec/neo4j/driver/session_spec.rb:42

# With documentation format
bundle exec rspec --format documentation
```

### Environment Variables
```bash
export TEST_NEO4J_URL=bolt://localhost:7687
export TEST_NEO4J_USER=neo4j
export TEST_NEO4J_PASS=password
```

## Test Status

**Current Status** (as of 2026-04-21):
- **388 examples total**
- **348 passing** ✅
- **40 failures** ❌

### Failing Test Categories
1. **Session/Transaction error handling** (~15 tests)
   - Error recovery scenarios
   - Transaction rollback edge cases
   - Connection failure handling

2. **Parameter validation** (~5 tests)
   - Invalid parameter types (Node, Relationship, Path)
   - Helpful error messages

3. **Temporal type roundtripping** (~6 tests)
   - DateTime as Ruby DateTime (not Time)
   - ZonedDateTime roundtrip with timezone
   - Offset-only datetime handling

4. **ResultStream** (~4 tests)
   - Field names in result
   - Reuse session after failure
   - Empty list after failure

5. **Miscellaneous** (~10 tests)
   - Service unavailable retry logic
   - Result spec edge cases

## References

### Bolt Protocol Specification
- **Official Docs**: https://neo4j.com/docs/bolt/current/
- **Protocol Versions**:
  - Bolt 4.0: https://7687.org/bolt/bolt-protocol-message-specification-4.html
  - Bolt 5.0: https://neo4j.com/docs/bolt/current/bolt/
- **PackStream Specification**: https://neo4j.com/docs/bolt/current/packstream/
- **Bolt Message Structures**: https://neo4j.com/docs/bolt/current/bolt-compatibility/

### Official Neo4j Drivers (Reference Implementations)

#### Java Driver (Reference Implementation)
- **GitHub**: https://github.com/neo4j/neo4j-java-driver
- **Most comprehensive**, used as reference for protocol implementation
- **Key Files**:
  - `driver/src/main/java/org/neo4j/driver/internal/packstream/` - PackStream
  - `driver/src/main/java/org/neo4j/driver/internal/messaging/` - Bolt messages
  - `driver/src/main/java/org/neo4j/driver/internal/value/` - Type system

#### Python Driver
- **GitHub**: https://github.com/neo4j/neo4j-python-driver
- **Async support**, good example of Pythonic API design
- **Key Files**:
  - `neo4j/_codec/` - PackStream and hydration
  - `neo4j/_sync/` - Synchronous implementation

#### JavaScript Driver
- **GitHub**: https://github.com/neo4j/neo4j-javascript-driver
- **TypeScript**, good type definitions
- **Key Files**:
  - `packages/core/src/internal/bolt-protocol/` - Protocol implementation
  - `packages/core/src/graph-types/` - Type system

#### Go Driver
- **GitHub**: https://github.com/neo4j/neo4j-go-driver
- **Key Files**:
  - `neo4j/internal/packstream/` - PackStream
  - `neo4j/dbtype/` - Graph types

#### .NET Driver
- **GitHub**: https://github.com/neo4j/neo4j-dotnet-driver

### Useful Comparisons

When implementing new features, check other drivers for:

1. **Type Mapping** - How they map Neo4j types to language types
   - Java: `LocalDateTime` → `java.time.LocalDateTime`
   - Python: `DateTime` → `neo4j.time.DateTime` (custom class)
   - JavaScript: `DateTime` → `DateTime` object (custom)
   - Ruby (this driver): `DateTime` → Ruby `Time` (with timezone)

2. **Error Handling** - Classification of errors
   - `ClientError` - User error (bad query, constraint violation)
   - `TransientError` - Temporary failure (retry possible)
   - `DatabaseError` - Server error

3. **Session Modes** - Read/write separation
   - `session.execute_read` - Read-only transaction
   - `session.execute_write` - Write transaction
   - Routing for cluster awareness

4. **Temporal Types** - How they handle timezones
   - Java uses `java.time.*` directly
   - Python has custom `neo4j.time.*` classes
   - JavaScript has custom classes
   - **This driver**: Uses Ruby `Time`/`Date` + custom types where needed

## Development Workflow

### Before Making Changes
1. Read `.claude/context.md` for architecture decisions
2. Check relevant official driver for reference
3. Verify against Bolt protocol spec if touching protocol layer

### Adding New Features

#### New Bolt Message Type
1. Add signature constant: `lib/neo4j/driver/bolt/message.rb`
2. Add message class if needed
3. Add packer: `lib/neo4j/driver/packstream/packer.rb`
4. Add hydration handler: `lib/neo4j/driver/bolt/connection.rb`
5. Add tests: `spec/neo4j/driver/bolt/`

#### New Graph Type
1. Add class: `lib/neo4j/driver/types.rb`
2. Implement `Comparable` if applicable
3. Add packer: `lib/neo4j/driver/packstream/packer.rb`
4. Add hydration handler: `lib/neo4j/driver/bolt/connection.rb`
5. Add tests: `spec/neo4j/driver/types/`

#### New Session/Transaction Feature
1. Check Java driver for reference
2. Update `lib/neo4j/driver/session.rb` or `transaction.rb`
3. Add tests: `spec/integration/session_spec.rb`

### Debugging Tips

#### View Bolt Protocol Wire Format
```ruby
# Enable debug logging (if implemented)
# Or use Wireshark with Neo4j Bolt dissector
```

#### Test Against Different Neo4j Versions
```bash
# Docker
docker run -p 7687:7687 -e NEO4J_AUTH=neo4j/password neo4j:4.4
docker run -p 7687:7687 -e NEO4J_AUTH=neo4j/password neo4j:5.0
```

#### Compare with Java Driver Behavior
```bash
# Clone Java driver
git clone https://github.com/neo4j/neo4j-java-driver
# Look at tests for expected behavior
```

## Code Style

### Naming Conventions
- Use Ruby conventions (snake_case, not camelCase)
- Match Java driver method names where sensible (e.g., `execute_write`, not `write_transaction`)
- Internal classes can differ from Java (optimize for Ruby idioms)

### Type Conventions
- Node labels → `:symbol`
- Relationship types → `:symbol`
- Result keys → `:symbol`
- Property keys → Can be string or symbol (stored as string, accessible both ways)

### Error Messages
- Be helpful: `"Cannot pack value of type #{value.class}"` not just `"Invalid value"`
- Include context: `"Transaction is already closed"` not just `"Invalid state"`
- Match Java driver error codes when possible

## Common Tasks

### Check Protocol Compatibility
```ruby
# Connection handshake shows negotiated version
connection.protocol.version # => "4.4"
```

### Run Single Failing Test
```bash
bundle exec rspec './spec/integration/session_spec.rb[1:2:3]'
```

### Debug Test Failure
```ruby
# Add to test:
puts result.inspect
puts result.summary.metadata.inspect
```

### Compare with Other Drivers
1. Check Java driver test: `testcases/integration/...`
2. Look for equivalent Python test: `tests/integration/...`
3. Verify protocol spec: https://neo4j.com/docs/bolt/current/

## Git Workflow

### Commit Messages
Follow format:
```
Brief summary (50 chars or less)

- Detailed point 1
- Detailed point 2
- Why this change was needed

Fixes: #issue-number (if applicable)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Before Committing
```bash
# Run tests
bundle exec rspec

# Check for debugging artifacts
git diff | grep -i "puts\|binding.pry\|debugger"
```

## Troubleshooting

### Tests Hang
- Connection not closing properly
- Infinite loop in result fetching
- Check: `@consumed` flag, connection state

### Wrong Type Returned
- Check hydration handler signature
- Verify PackStream packing format
- Compare with Java driver

### Precision Loss in Temporal Types
- Don't use floating point arithmetic for nanoseconds
- Use `nsec` or `subsec * 1_000_000_000`
- See `.claude/context.md` for details

### Timezone Issues
- **Signature 0x46** (offset) - straightforward UTC offset
- **Signature 0x66** (zone name) - requires double offset adjustment!
- See `.claude/context.md` for critical 0x66 details

## Performance Considerations

### Result Streaming
- Results are lazy-loaded
- Don't call `.to_a` on huge results unless necessary
- Use `.each` for streaming

### Connection Pooling
- Driver maintains connection pool
- Sessions reuse connections
- Close sessions to release connections

### Parameter Packing
- Large parameters are packed inline
- No special optimization for repeated values
- Keep parameters reasonably sized

## Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in version.rb
- [ ] Git tag created
- [ ] Gem published

## Getting Help

- **Bolt Protocol**: https://neo4j.com/docs/bolt/current/
- **Neo4j Community**: https://community.neo4j.com/
- **Driver Issues**: (GitHub issues URL when available)
- **Compare with Java Driver**: https://github.com/neo4j/neo4j-java-driver
