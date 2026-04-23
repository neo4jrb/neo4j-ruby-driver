# Decision Log

This file records important architectural and design decisions made during development.

> **Note**: This is a living document. Append new decisions chronologically with date and context.

## 2026-04-22: Session#run Signature - Separate Parameters and Config

**Decision**: Use explicit `def run(query, parameters = {}, config = {})` signature instead of merging parameters and config with keyword argument extraction.

**Rationale**:
- Supports same key in both parameters and config: `session.run(query, { metadata: 'param' }, metadata: { config: true })`
- Explicit separation is clearer than implicit extraction
- Matches pattern used in other methods (execute_read/write accept timeout and metadata explicitly)

**Example**:
```ruby
session.run('RETURN $x', x: 1)                    # parameters only
session.run('RETURN $x', { x: 1 }, timeout: 60)   # parameters + config
session.run('RETURN $x', {}, timeout: 60)         # config only
```

## 2026-04-22: Timeout Units - Seconds in API, Milliseconds in Protocol

**Decision**: All timeout parameters in Ruby API accept seconds (or ActiveSupport::Duration), converted internally to milliseconds for Bolt protocol.

**Rationale**:
- Ruby convention: `sleep(60)` means 60 seconds
- User-facing API should be idiomatic Ruby
- Bolt protocol requires milliseconds - this is an implementation detail
- Added `timeout_to_milliseconds` helper for conversion

**Implementation**:
```ruby
def timeout_to_milliseconds(timeout)
  return nil unless timeout
  timeout_seconds = timeout.respond_to?(:to_i) ? timeout.to_i : timeout
  (timeout_seconds * 1000).to_i
end

run_extra = {
  db: @options[:database],
  tx_timeout: timeout_to_milliseconds(timeout),
  tx_metadata:
}.compact  # Remove nil values
```

## 2026-04-22: Bookmark Behavior - Replace, Not Accumulate

**Decision**: Bookmarks are **replaced** after each committed transaction, not accumulated.

**Rationale**:
- Matches Java driver behavior (the reference implementation)
- Each bookmark represents the **latest** point in transaction log
- `session.last_bookmarks` returns a Set with **0 or 1 bookmark**
- Multiple accumulated bookmarks would be semantically incorrect

**Java driver reference**: `BookmarkManagerTest.java` line 72-84 verifies unique bookmarks across transactions

**Implementation**:
```ruby
def update_bookmarks(bookmarks)
  # Replace bookmarks (don't accumulate)
  @last_bookmarks = Set.new(Array(bookmarks).map(&Bookmark.method(:new)))
end
```

## 2026-04-22: Remove Defensive `.dup.freeze` from `last_bookmarks`

**Decision**: Return `@last_bookmarks` directly without `.dup.freeze`.

**Rationale**:
- **Trust the caller** - If they want to mutate returned Set, that's their choice
- No special vulnerability in modifying bookmarks
- "This could be claimed about any returned object" - no reason to special-case bookmarks
- Consistent with Ruby philosophy: don't prevent users from doing what they want

**Before**:
```ruby
def last_bookmarks
  @last_bookmarks.dup.freeze
end
```

**After**:
```ruby
def last_bookmarks
  @last_bookmarks
end
```

## 2026-04-22: Zeitwerk File Organization - One Class Per File

**Decision**: Refactor entire codebase to follow strict Zeitwerk convention of one class/module per file.

**Rationale**:
- **Idiomatic Ruby** - Standard file organization pattern
- **Proper autoloading** - Zeitwerk expects file path to match constant path
- **Better discoverability** - Easy to find where classes are defined
- **Easier navigation** - IDE/editor tools work better with one class per file

**Changes**:
- Split `bolt/message.rb` → `bolt/message/*.rb` (Success, Failure, Record, Ignored)
- Split `session.rb` → Extract `access_mode.rb`
- Split `result.rb` → `result.rb`, `record.rb`, `summary.rb`
- Split `types.rb` → `types/*.rb` (Node, Relationship, Path, Time, LocalTime, LocalDateTime, Duration, Point, UnboundRelationship)

**Nested classes allowed**: Implementation details like `Summary::Query`, `Path::Segment` can stay nested.

## 2026-04-22: Polymorphism Refactoring (Planned, Postponed)

**Decision**: Refactor Bolt message handling from type checking (`is_a?`, `case/when`) to polymorphic dispatch using Command Pattern.

**Status**: Plan created, implementation postponed for later

**Problem**:
- Type checking scattered across Session, Transaction, Result, Connection
- Duplicated error mapping logic in 3 locations
- Violates "Tell, Don't Ask" principle

**Proposed Solution**:
- Create `Response` base class with polymorphic interface
- Each message implements `handle_in_session`, `handle_in_transaction`, `handle_in_result`
- Extract exception mapping to `ExceptionMapper` class

**Plan location**: `/Users/heinrich/.claude/plans/sparkling-swinging-glacier.md`

## Future Decisions

Add new decisions here with:
- **Date**: When decision was made
- **Decision**: What was decided
- **Rationale**: Why this approach
- **Context**: Related issues, discussions, or code examples
- **Status**: If applicable (e.g., "implemented", "planned", "reconsidered")
