# Session History

This file records important work done in Claude Code sessions and context that should persist.

> **Note**: Append to this file after each significant session to preserve context across sessions.

## Session 2026-04-22: Timeout, Bookmarks, and Zeitwerk Refactoring

### Key Work Completed

1. **Fixed Session#run Signature**
   - Changed to explicit `parameters` and `config` parameters
   - Allows same key in both (e.g., `metadata` as param and config)
   - Cleaner than previous `**options` extraction approach

2. **Converted Timeouts to Seconds**
   - All Ruby API timeouts now accept seconds (user-facing)
   - Internally converted to milliseconds for Bolt protocol
   - Added `timeout_to_milliseconds` helper
   - Used `.compact` to remove nil values from hashes

3. **Fixed Bookmark Behavior**
   - Bookmarks now **replace** instead of accumulate
   - Matches Java driver reference implementation
   - `last_bookmarks` returns Set with 0 or 1 bookmark
   - Removed unnecessary `.dup.freeze` (trust the caller)

4. **Zeitwerk File Organization Refactoring**
   - Split all multi-class files into one class per file
   - **Bolt messages**: Success, Failure, Record, Ignored → separate files
   - **Session**: Extracted AccessMode module
   - **Result**: Split into Result, Record, Summary
   - **Types**: Split 9 classes (Node, Relationship, Path, Time, LocalTime, LocalDateTime, Duration, Point, UnboundRelationship)

5. **Created Documentation**
   - Added "Coding Style & Preferences" section to context.md
   - Added "Maintainer Preferences & Workflow" to DEVELOPMENT.md
   - Created DECISIONS.md for architectural decision log
   - Created this SESSION_HISTORY.md file

### Important Learnings

- **Heinrich's preferences**:
  - Idiomatic Ruby over defensive programming
  - Trust callers (no unnecessary guards)
  - Explicit over clever
  - Question over-engineering
  - Always ask before commits

- **Code patterns established**:
  - Use `.compact` to remove nils from hashes
  - Ruby 3.1+ hash value omission: `metadata:` instead of `metadata: metadata`
  - Method references: `&Bookmark.method(:new)`
  - `Array()` conversion for ensuring array type

- **Postponed work**:
  - Polymorphism refactoring (plan created in `/Users/heinrich/.claude/plans/sparkling-swinging-glacier.md`)
  - Will replace type checking with Command Pattern when resumed

### Test Status
- **388 examples, 40 failures** (no regressions from refactoring)
- All structural changes (Zeitwerk) completed successfully
- Types and messages properly split and autoloading correctly

### Files Modified
- `.claude/context.md` - Added coding style section, updated architecture overview
- `DEVELOPMENT.md` - Added maintainer preferences section
- `lib/neo4j/driver/session.rb` - Timeout conversion, AccessMode extracted
- `lib/neo4j/driver/result.rb` - Split into three files
- `lib/neo4j/driver/types.rb` - Split into nine files
- `lib/neo4j/driver/bolt/message.rb` - Split into four message classes
- Created: `access_mode.rb`, `record.rb`, `summary.rb`, 9 types files, 4 message files
- Created: `.claude/DECISIONS.md`, `.claude/SESSION_HISTORY.md`

### Git Commits
1. `d4d1c77` - Convert timeouts to seconds and fix bookmark behavior
2. `046a13c` - Remove .rspec_status from git tracking
3. `4dfa9c7` - Refactor to follow Zeitwerk conventions (one class per file)
4. `643b1d5` - Split Types module following Zeitwerk conventions

### For Next Session

**Context to remember**:
- Polymorphism refactoring plan is ready but postponed
- All files now follow Zeitwerk conventions (done!)
- Heinrich values simple, idiomatic Ruby - always question complexity
- Check DECISIONS.md for rationale behind past choices
- Always read code directly as source of truth

**Known issues** (40 test failures):
- Session/transaction error handling edge cases (~15)
- Parameter validation for invalid types (~5)
- Temporal type roundtripping (~6)
- ResultStream tests (~4)
- Other misc (~10)

**Next potential work**:
- Fix remaining test failures
- Implement postponed polymorphism refactoring
- Additional features as requested by Heinrich

---

## Template for Future Sessions

### Session YYYY-MM-DD: Brief Title

**Key Work Completed:**
1. What was done
2. Major changes

**Important Learnings:**
- New patterns discovered
- Preferences clarified

**Test Status:**
- Number passing/failing

**For Next Session:**
- Context to carry forward
- Pending work

---
