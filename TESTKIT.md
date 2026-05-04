# Testkit status

Walk-down log for passing the [testkit](https://github.com/neo4j-drivers/testkit)
suite. Update after each meaningful change.

Run:
- `./bin/run-testkit neo4j` — integration suite, needs a Neo4j on `localhost:7687` (enterprise for multi-db tests). Set `TEST_NEO4J_VERSION` to the `major.minor` of your local server.
- `./bin/run-testkit stub` — protocol suite, no Neo4j required (uses testkit's bundled `boltstub`).

See `testkit-backend/README.md` for full setup notes.

Two CI gates, one per target:
- `.github/testkit-baseline.txt` ↔ `.github/workflows/testkit.yml`
- `.github/testkit-stub-baseline.txt` ↔ `.github/workflows/testkit-stub.yml`

Each is a sorted list of tests that must keep passing. After moving
the numbers, **also update the baseline file** (add lines for new
passers; remove with reason in the commit message if a test
legitimately stops being expected to pass). Refresh either with
`bin/refresh-testkit-baseline [neo4j|stub]`.

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
| 2026-05-01 | tests/neo4j | 121 | 87 | 0 | 1 | 33 | +2 pass / -2 errors. Added `Driver#supports_multi_db?` (delegates to `connection.protocol.supports_multiple_databases?`, true for Bolt 4+) and the `CheckMultiDBSupport` request handler. Required adding a Zeitwerk inflection so `check_multi_db_support.rb` resolves to `CheckMultiDBSupport` (capital `DB`). `test_multi_db_non_existing` started passing as a side effect after switching the local Neo4j container to enterprise — testkit defaults `TEST_NEO4J_EDITION=enterprise`, so against community it ran instead of self-skipping and failed on `DROP DATABASE`. |
| 2026-05-01 | tests/neo4j | 121 | **88** | 0 | 0 | 33 | +1 pass / -1 error. Custom address resolver: `Bolt::Connection#connect` now iterates `resolved_addresses` (delegates to `@options[:resolver]` callable when set, falling back to the URI host:port). Backend's `NewDriver` accepts `resolverRegistered`, installs a Proc that round-trips through `Response::ResolverResolutionRequired` and reads back the matching `ResolverResolutionCompleted` request. Three side fixes were needed: (a) socket connect via `Socket.tcp(connect_timeout:)` so unreachable resolved addresses fail fast, (b) `Bolt::Connection` now records the actually-connected `address`, (c) `Summary#server` returns that instead of the URI's host (which is `*` when a resolver is in play). **Zero failures and zero errors in `tests/neo4j` now.** |
| 2026-05-02 | tests/stub  | 1601 | 9 | 5 | 29 | 1578 | Initial stub baseline. Most of the 1578 skips are gated on `Feature:Bolt:X.Y` flags we don't yet advertise; 8 of the 29 errors are routing (`neo4j://` scheme not implemented); the rest of the fail/error cluster is `result_scope` / `tx_lifetime` (driver should raise on read after consume / op after tx close in a few cases we don't yet cover). Bootstrap PR establishes the gate. |
| 2026-05-02 | tests/stub  | 1601 | **14** | 3 | 26 | 1578 | +5 pass / -2 fail / -3 error. **Routing skeleton (slice 1):** `neo4j://` scheme is now recognised; `Routing::ServerAddress` / `Routing::RoutingTable` / `Routing::LoadBalancer` added; `Bolt::Message.route` + `Bolt::Connection#route` send the Bolt 4.3+ ROUTE message and parse the table; `Driver` dispatches to `LoadBalancer` (per-server connection pools, round-robin within role) when scheme is routing; `Session` threads `access_mode`/`database` to `acquire_connection`. Side fixes: `Bolt::Connection#connect` rescues broader errors so `<EXIT>`-style stubs flow through the address-retry loop; `Session#run` only sends `tx_metadata` when non-empty; spec helper defaults `TEST_NEO4J_SCHEME` to `bolt` (the integration suite is direct, not routed). 5 of the 8 routing-related verify_connectivity tests now pass; the 3 remaining failures/errors are direct-mode or routing follow-up scope. |
| 2026-05-03 | tests/stub  | 1601 | 14 | 3 | 26 | 1578 | **Routing slice 2 (correctness, no test-count change):** per-operation connection lease + failure-driven routing-table refresh. `Session` no longer memoises `@connection`; each `run` / `begin_transaction` / `execute_read` / `execute_write` acquires a fresh connection with that operation's access mode and the in-flight Result/Transaction owns it. `Result` self-releases on SUCCESS / IGNORED / `discard!` via a new `on_release:` callback; `Transaction` self-releases on commit / rollback / failed BEGIN via the same hook. `LoadBalancer#acquire` now refreshes the routing table once on `ServiceUnavailableException` before retrying — covers leader change / topology shift cases. Test counts unchanged because the existing routing tests use single-mode sessions; the win is in mixed-mode and pool-utilisation correctness, which the deeper routing tests (gated on Bolt feature flags) will exercise. |
| 2026-05-03 | tests/stub  | 1601 | **93** | 18 | 470 | 1141 | +79 pass / +15 fail / +444 error / -437 skip. Two intertwined fixes: (a) Bolt handshake byte-order bug — wire format is `[reserved, range, minor, major]` but our constants put major in byte 2 and minor in byte 3, so we always negotiated 4.4 (the only palindrome) regardless of what we proposed. Per `boltstub`'s `decode_versions`. Fixed; verified we now negotiate 5.7 against Neo4j 5.26. (b) Honest advertisement of `Feature:Bolt:4.4` in `GetFeatures` — unlocks ~600 tests gated on it. Most newly-running tests are still failing (we don't implement features they exercise — fetch-size + DISCARD, qid-based stream control, AUTH_MANAGED, BOOKMARK_MANAGER, etc.), but the ones we do support now pass. **One regression:** `test_discards_on_session_close` was previously passing only on its `v3` parameterisation; now `v4x4` runs too and fails because we always `PULL n:-1` instead of `PULL n + DISCARD remainder` — same root cause as backlog #12. Removed from baseline; will return when fetch-size lands. Handshake is restricted to Bolt 4.4 only for now: 5.x HELLO needs `bolt_agent` and 5.1+ moves auth to a separate LOGON message — backlog #13. |
| 2026-05-03 | tests/neo4j | 121 | **92** | 0 | 0 | 29 | +4 pass / -4 skip. Side-effect of the handshake byte-order fix + `Feature:Bolt:4.4` advertisement: `test_protocol_version_information`, `test_summary_counters_case_2`, `test_multi_db`, `test_multi_db_various_databases` were all skipping with "no common protocol version between server and driver" — they now run and pass. |

The cluster sections below are scoped to the most recent run of each
target. The stub suite is much larger and walk-down is just starting;
detailed clusters there will appear once we expand coverage.

## tests/neo4j — Error clusters (0, was 1)

None. 🎉

## tests/neo4j — Failures (0, was 1)

None. 🎉

## tests/neo4j — Skips (33)

Driven entirely by our empty `GetFeatures` response. Unique skip reasons:

- `Feature.API_DRIVER_VERIFY_CONNECTIVITY` — **we have this**; just need to advertise → several skips move to pass.
- `Feature.API_TYPE_TEMPORAL` — **mostly implemented**; advertising will flip skip → mix of pass/fail to fix.
- `Feature.API_TYPE_SPATIAL` / `Feature.API_TYPE_VECTOR` / `Feature.API_SUMMARY_GQL_STATUS_OBJECTS` — honest skips.
- `No common version between server and driver: (4, 0)` — not a feature gate; version negotiation detail.

## tests/stub — Errors / Failures / Skips (29 / 5 / 1578)

Headlines (full breakdown deferred until walk-down starts):

- **~1500 skips** are gated on `Feature:Bolt:X.Y` flags we don't yet advertise.
- **8 errors** are routing tests (`neo4j://` scheme not implemented).
- **~17 fail/error** are `result_scope` / `tx_lifetime` corner cases (driver should raise on read after consume / op after tx close in paths we don't yet cover).
- A handful of misc.

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
9. ~~Resolver hook — `Driver.new(uri, resolver:)`. Connection iterates resolved addresses with per-attempt `connect_timeout`. Backend wires `resolverRegistered` round-trip.~~ Done.
10. **`tests/stub` work** — bootstrap done (baseline + CI). Walk-down sequence:
    1. Advertise Bolt feature flags (`Feature:Bolt:4.4`, `5.0`–`5.7`, `6.0`); ~1500 tests start running.
    2. `tx_lifetime` / `result_scope` driver fixes — small.
    3. **Routing** — slices 1–2 done (skeleton + per-operation lease + failure-driven refresh). Slice 3: leader-switch + transient retry. Slice 4: per-database routing + ROUTE `db` field. Slice 5: routing context + multiple seed routers. Slice 6: bookmark/lifecycle edge cases.
11. **JRuby integration** — wire the JRuby implementation (mostly ready locally) into the existing test/CI matrix.
12. **Session-close cancel semantics** — `Session#close` currently calls `Result#buffer`, which pulls every remaining `RECORD` off the wire just to discard them client-side. The block-form `Driver#session` then silently swallows any failure that drain surfaces. Java-faithful behaviour: send `DISCARD`/`RESET` to abandon the stream server-side; nothing surfaces; no swallow needed. Also requires fixing `Connection#reset!` to drain by terminal-for-RESET, not by queue-pop count (each in-flight `PULL` produces N records + 1 terminal). The integration spec `'reports failure in close'` encodes the wrong contract today and would need to flip. See TODO in `Session#close`. (Same root cause as the regression on `test_discards_on_session_close.v4x4` — fetch-size + DISCARD-of-remainder.)
13. **Bolt 5.x HELLO + LOGON** — handshake is restricted to Bolt 4.4 because 5.x HELLO needs a `bolt_agent` map (driver/lang metadata) and 5.1+ moves auth out of HELLO into a separate LOGON message. V5 protocol class needs an override on `build_hello_message` plus a `build_logon_message` for 5.1+. After this lands we can advertise `Feature:Bolt:5.0` through `Feature:Bolt:5.7` and propose ranges in the handshake (Bolt 4.3+ encoding) to negotiate higher.
13. **Temporal type advertisement + gaps** once we flip `API_TYPE_TEMPORAL` on.
14. **Driver-level features** — async PULL / fetch size, TLS, notifications, auth token manager, impersonation. Each a session or more.

## Update protocol

After each change that moves numbers:

1. Re-run the affected target(s): `./bin/run-testkit neo4j` and/or `./bin/run-testkit stub`.
2. Append a new row to **Current baseline** with the date, target, and delta.
3. Update the matching `tests/<target>` cluster section if the shape changed, not just the counts.
4. Refresh the baseline file: `bin/refresh-testkit-baseline [neo4j|stub]`.
5. Mention the cluster (or size delta) and the affected target in the commit message.
