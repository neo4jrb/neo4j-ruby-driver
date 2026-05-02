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
| 2026-04-26 | tests/neo4j | 121 | 73 | 9 | 8 | 32 | +5 pass / −5 errors. (a) Session#begin_transaction now accepts `metadata:` and `timeout:` kwargs; SessionBeginTransaction and managed-tx handlers thread them through. (b) Empty `errorId` from RetryableNegative now raises ClientGeneratedError → Response::FrontendError instead of ClientException → DriverError, matching what testkit asserts on the "client code raised" path. |
| 2026-04-27 | tests/neo4j | 121 | 76 | 9 | 5 | 31 | +3 pass / −3 errors as side benefit of fixing `Session#timeout_to_milliseconds` precision: was using `to_i` and rounding 100ms (= 0.1s) down to 0, so timeout-honouring tests waited the full retry budget and then testkit timed out the backend connection. Switched to `to_f`. Three timeout tests (`test_tx_timeout` × 2, `test_autocommit_transactions_should_support_timeout`) now pass; full testkit runtime dropped from 241s → 6s. |
| 2026-04-28 | tests/neo4j | 121 | 82 | 3 | 3 | 33 | +6 pass. Richer `Summary` payload: pass `metadata[:type]` raw (`'rw'`) instead of mapped symbol; pass `metadata[:notifications]/[:plan]/[:profile]` through with deep-stringified keys (testkit only checks they're list/dict); encode `query.parameters` via `Cypher.from_ruby`. `test_agent_string` is environment-dependent — `bin/run-testkit` and CI now set `TEST_NEO4J_VERSION` so testkit's expected agent matches the server. |
| 2026-04-30 | tests/neo4j | 121 | 84 | 1 | 3 | 33 | +2 pass. `Transaction#rollback` now raises `ClientException` when the tx is already closed (committed or rolled back) instead of silently no-op'ing. The two `test_should_not_rollback_a_*` tests now pass. `Transaction#close` is unaffected — it only calls rollback when `@open` is true, so idempotent close still works. |
| 2026-04-30 | tests/neo4j | 121 | 85 | 0 | 3 | 33 | +1 pass / -1 fail. Auto-commit `Session#run` now harvests the bookmark from the PULL SUCCESS metadata (was only doing it on explicit-tx COMMIT). Done via a new `on_summary` callback on `Result` that the session wires to `update_bookmarks`; `Transaction`-bound results don't pass it. Side benefit: extracted `finalize_success` / `finalize_failure` helpers so the SUCCESS/FAILURE branches no longer duplicate `Summary.new` four ways. **Zero failures left** — only the 3 MultiDB errors remain. |
| 2026-05-01 | tests/neo4j | 121 | **87** | 0 | 1 | 33 | +2 pass / -2 errors. Added `Driver#supports_multi_db?` (delegates to `connection.protocol.supports_multiple_databases?`, true for Bolt 4+) and the `CheckMultiDBSupport` request handler. Required adding a Zeitwerk inflection so `check_multi_db_support.rb` resolves to `CheckMultiDBSupport` (capital `DB`). `test_multi_db_non_existing` started passing as a side effect after switching the local Neo4j container to enterprise — testkit defaults `TEST_NEO4J_EDITION=enterprise`, so against community it ran instead of self-skipping and failed on `DROP DATABASE`. |

## Error clusters (1, was 3)

| Count | Root cause | Fix shape |
| ----: | ---------- | --------- |
| 1 | `test_direct_driver.test_custom_resolver`. | Driver-side resolver hook — accepts `resolver:` callable, calls it on connection acquisition; backend wires it to `ResolverResolutionRequired` / `ResolverResolutionCompleted`. |

## Failures (0, was 1)

None. 🎉

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
5. ~~Richer `Summary` (query type code, parameters, notifications, plan, profile, agent-string env).~~ Done.
6. ~~Tx-run rollback assertions — `Transaction#rollback` raises on already-closed tx.~~ Done.
7. ~~Bookmark round-trip — auto-commit `Session#run` harvests bookmark from PULL SUCCESS.~~ Done.
8. ~~`CheckMultiDBSupport` handler + `Driver#supports_multi_db?` (also unblocked `test_multi_db_non_existing` after switching local server to enterprise).~~ Done.
9. **Resolver hook** — `Driver.new(uri, resolver:)`. One error (`test_custom_resolver`).
10. **`tests/stub`** (protocol-version stub-server tests) — aligns with the v3–v58 protocol-range goal.
11. **JRuby integration** — wire the JRuby implementation (mostly ready locally) into the existing test/CI matrix.
12. **Temporal type advertisement + gaps** once we flip `API_TYPE_TEMPORAL` on.
13. **Driver-level features** — routing (`neo4j://`), async PULL / fetch size, TLS, notifications, auth token manager, impersonation. Each a session or more.

## Update protocol

After each change that moves numbers:

1. Re-run `./bin/run-testkit neo4j`.
2. Append a new row to **Current baseline** with the date and delta.
3. Update the **Error clusters** / **Failures** / **Skips** sections if the shape changed, not just the counts.
4. Mention the cluster (or size delta) in the commit message.
