# Testkit status

Walk-down log for passing the [testkit](https://github.com/neo4j-drivers/testkit)
suite. Update after each meaningful change.

Run: `./bin/run-testkit neo4j` (see `testkit-backend/README.md` for env
prerequisites).

CI gates on `.github/testkit-baseline.txt` — a sorted list of tests that
must keep passing. After moving the numbers, **also update the baseline
file** (add lines for new passers; remove with reason in the commit
message if a test legitimately stops being expected to pass).

## Current baseline

| Date       | Target | Tests | Pass | Fail | Error | Skip | Notes |
| ---------- | ------ | ----: | ---: | ---: | ----: | ---: | ----- |
| 2026-04-23 | tests/neo4j | 121 | 33 | 5 | 80 | 33 | Initial measurement. |
| 2026-04-23 | tests/neo4j | 121 | 42 | 8 | 69 | 32 | +9 pass / -11 errors. Fixed Summary payload (added missing `notifications`, `plan`, `profile`, `resultAvailableAfter`, `resultConsumedAfter`, populated `serverInfo` from real metadata, fixed `counters` shape). Honest `GetFeatures` advertises 5 features we genuinely have. Newly-running tests revealed the next layer of failures (graph types, tx config). |
| 2026-04-26 | tests/neo4j | 121 | 61 | 17 | 13 | 33 | +19 pass / −56 errors. Implemented managed transactions (SessionReadTransaction / SessionWriteTransaction) with the RetryableTry / RetryablePositive / RetryableNegative callback dance via a nested dispatch loop inside the request handler. Tests previously stuck behind the missing handler now run; many pass, the rest hit the next layer of unimplemented behaviour. |
| 2026-04-26 | tests/neo4j | 121 | 68 | 10 | 13 | 33 | +7 pass / −7 fail. Cypher.from_ruby now emits proper CypherNode / CypherRelationship / CypherPath instead of stringifying via to_s — labels and props are wrapped through from_ruby so they round-trip as CypherList<CypherString> and CypherMap<CypherX> as testkit expects. |
| 2026-04-26 | tests/neo4j | 121 | **73** | 9 | 8 | 32 | +5 pass / −5 errors. (a) Session#begin_transaction now accepts `metadata:` and `timeout:` kwargs; SessionBeginTransaction and managed-tx handlers thread them through. (b) Empty `errorId` from RetryableNegative now raises ClientGeneratedError → Response::FrontendError instead of ClientException → DriverError, matching what testkit asserts on the "client code raised" path. |

## Error clusters (13, was 69)

| Count | Root cause | Fix shape |
| ----: | ---------- | --------- |
| 5 | `OSError: cannot read from timed out object` / `TimeoutError`. | Some retry-budget tests are slow; possibly real driver behaviour, possibly testkit's frontend timeout. Investigate per-test. |
| 4 | `Client-generated error from testkit` (DriverError surfacing the message we raise on `RetryableNegative` with empty `errorId`). | Tests deliberately call `RetryableNegative` to test client-error propagation; our generic `ClientException` may not match what testkit asserts on. Refine the synthetic error shape. |
| 1 | `Should be MultiDBSupport but was UnknownTypeError: ChangeDatabase`. | Multi-database test path needs `Feature:API:Driver.ExecuteQuery` or similar advertisement + handler. |
| 1 | `BackendError: IOError: Unexpected end of stream`. | Connection bookkeeping issue in some path; needs targeted reproduction. |
| 1 | Invalid-URL test expects a specific `DriverError` shape (we raise `ServiceUnavailableException` without a `code`). | Map `Errno::*` / DNS failures to a standardised error code, or adjust the expected feature gate. |
| 1 | `DROP DATABASE … WAIT` — needs enterprise + the `WAIT` clause support. | CI now uses enterprise so the underlying support is there; check whether our query parameter handling supports it. |

## Failures (17, was 8)

Dominated by graph value types, surfaced via the now-running managed-tx
tests. Most failures cluster:

- **Graph types in record values** (~10 tests): `CypherNode` / `CypherRelationship` / `CypherPath` not emitted — they fall through to the `to_s` `CypherString` fallback in `Cypher.from_ruby`. Implement proper `from_ruby` paths for the graph types.
- **Tx configuration** (~2): `SessionBeginTransaction` ignores `txMeta` / `timeout`. Driver's `Session#begin_transaction` doesn't accept config.
- **Specific error class assertions** (~2): tests assert a particular `DriverError` shape we don't produce (e.g. invalid bookmark message, parameter validation messages).
- **Bookmark round-trip** (~1): `test_can_pass_bookmark_into_next_session`.
- **Other** (~2): `assertIsInstance(None, dict)` style — Summary fields we return as `nil` when testkit expects a (possibly empty) dict.

## Skips (33)

Driven entirely by our empty `GetFeatures` response. Unique skip reasons:

- `Feature.API_DRIVER_VERIFY_CONNECTIVITY` — **we have this**; just need to advertise → several skips move to pass.
- `Feature.API_TYPE_TEMPORAL` — **mostly implemented**; advertising will flip skip → mix of pass/fail to fix.
- `Feature.API_TYPE_SPATIAL` / `Feature.API_TYPE_VECTOR` / `Feature.API_SUMMARY_GQL_STATUS_OBJECTS` — honest skips.
- `No common version between server and driver: (4, 0)` — not a feature gate; version negotiation detail.

## Prioritised backlog

Roughly decreasing return-per-effort:

1. ~~Counters payload fix + honest `GetFeatures`.~~ Done.
2. ~~Managed transactions (the retry-callback dance).~~ Done.
3. ~~Graph value types in record conversion.~~ Done.
4. ~~Tx configuration (`metadata`/`timeout` on `begin_transaction`) + RetryableNegative empty-errorId → FrontendError.~~ Done.
5. **Richer `Summary`** (query text, query type, server info, notifications). Several remaining failures look like `None is not an instance of <class 'dict'>` / `'Neo4j/2026.03' != 'Neo4j/5.0'` — Summary fields we either don't populate or populate with values testkit doesn't expect.
6. **Bookmark round-trip polish.** Remaining "0 != 1" style failures.
7. **Temporal type advertisement + gaps** once we flip `API_TYPE_TEMPORAL` on.
8. **MultiDB feature handler** — `CheckMultiDBSupport` / similar; advertise + implement.
9. **Time-budget retry tests** — 4 errors are tests deliberately exhausting `max_transaction_retry_time`; investigate whether these need a backend fix or driver-side timing.
10. **Driver-level features** — routing (`neo4j://`), async PULL / fetch size, TLS, notifications, auth token manager, impersonation. Each a session or more.
11. **`tests/stub`** (protocol-version stub-server tests) — aligns with the v3–v58 protocol-range goal.

## Update protocol

After each change that moves numbers:

1. Re-run `./bin/run-testkit neo4j`.
2. Append a new row to **Current baseline** with the date and delta.
3. Update the **Error clusters** / **Failures** / **Skips** sections if the shape changed, not just the counts.
4. Mention the cluster (or size delta) in the commit message.
