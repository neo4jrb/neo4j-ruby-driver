# Testkit status

Walk-down log for passing the [testkit](https://github.com/neo4j-drivers/testkit)
suite. Update after each meaningful change.

Run: `./bin/run-testkit neo4j` (see `testkit-backend/README.md` for env
prerequisites).

## Current baseline

| Date       | Target | Tests | Pass | Fail | Error | Skip | Notes |
| ---------- | ------ | ----: | ---: | ---: | ----: | ---: | ----- |
| 2026-04-23 | tests/neo4j | 121 | 33 | 5 | 80 | 33 | Initial measurement. |

## Error clusters (80)

| Count | Root cause | Fix shape |
| ----: | ---------- | --------- |
| 63 | Missing handlers `SessionReadTransaction` / `SessionWriteTransaction`. | Implement managed-tx callback protocol: the backend emits `RetryableTry{sessionId, txId}`; testkit then sends `Transaction*` requests against the emitted `txId`; on finish, testkit sends `RetryablePositive{sessionId}` (→ commit) or `RetryableNegative{sessionId, errorId}` (→ propagate retryable). |
| 11 | `SummaryCounters.__init__()` missing `containsSystemUpdates` / `containsUpdates` / `systemUpdates`. | Extend `counters_payload` in `dispatcher.rb`. Two are boolean roll-ups, one is an integer counter. |
| 1 | Invalid-URL test expects a specific `DriverError` shape (we raise `ServiceUnavailableException` without a `code`). | Map `Errno::*` / DNS failures to a standardised error code, or adjust the expected feature gate. |
| 1 | `DROP DATABASE … WAIT` — community edition rejects it (`Neo.ClientError.Statement.UnsupportedAdministrationCommand`). | Resolve when we advertise enterprise-only features properly, or run against enterprise. |

## Failures (5)

| Test | Root cause |
| ---- | ---------- |
| `test_session_run.test_can_return_node` | Record conversion doesn't emit `CypherNode`. |
| `test_session_run.test_can_return_relationship` | Record conversion doesn't emit `CypherRelationship`. |
| `test_session_run.test_can_return_path` | Record conversion doesn't emit `CypherPath`. |
| `test_bookmarks.test_can_pass_bookmark_into_next_session` | Bookmark wiring — initial-bookmarks config and/or round-trip. |
| `test_tx_run.test_tx_configuration` | Tx metadata / timeout handling in managed path. |

## Skips (33)

Driven entirely by our empty `GetFeatures` response. Unique skip reasons:

- `Feature.API_DRIVER_VERIFY_CONNECTIVITY` — **we have this**; just need to advertise → several skips move to pass.
- `Feature.API_TYPE_TEMPORAL` — **mostly implemented**; advertising will flip skip → mix of pass/fail to fix.
- `Feature.API_TYPE_SPATIAL` / `Feature.API_TYPE_VECTOR` / `Feature.API_SUMMARY_GQL_STATUS_OBJECTS` — honest skips.
- `No common version between server and driver: (4, 0)` — not a feature gate; version negotiation detail.

## Prioritised backlog

Roughly decreasing return-per-effort:

1. **Counters payload fix + honest `GetFeatures`.** ~14 errors/skips move to pass; ~30 min.
2. **Managed transactions (the retry-callback dance).** 63 errors reclassify; many pass, rest cluster into smaller real categories. ~2–3 hours.
3. **Graph value types (`CypherNode` / `CypherRelationship` / `CypherPath`)** in record conversion. Clears the 3 record-related failures and unlocks more in `tests/neo4j/datatypes`.
4. **Richer `Summary`** (query text, query type, server info, notifications). Needed by `test_summary` tests.
5. **Bookmark round-trip polish.**
6. **Temporal type advertisement + gaps** once we flip `API_TYPE_TEMPORAL` on.
7. **Driver-level features** — routing (`neo4j://`), async PULL / fetch size, TLS, notifications, auth token manager, impersonation. Each a session or more.
8. **`tests/stub`** (protocol-version stub-server tests) — aligns with the v3–v58 protocol-range goal.

## Update protocol

After each change that moves numbers:

1. Re-run `./bin/run-testkit neo4j`.
2. Append a new row to **Current baseline** with the date and delta.
3. Update the **Error clusters** / **Failures** / **Skips** sections if the shape changed, not just the counts.
4. Mention the cluster (or size delta) in the commit message.
