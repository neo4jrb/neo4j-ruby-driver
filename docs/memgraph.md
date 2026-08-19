# Memgraph compatibility

[Memgraph](https://memgraph.com) is an open-source, in-memory graph database
that speaks the **Bolt protocol** and **Cypher**, by design, so Neo4j drivers
can connect to it. This driver works against Memgraph over a direct `bolt://`
connection **with no code changes** — the gaps below are Memgraph feature/dialect
differences, not driver bugs, and the driver degrades gracefully on all of them.

> Status: **community-verified, not officially supported.** Measured against
> **Memgraph v3.12.0** on **both flavors** — MRI (pure-Ruby Bolt) and JRuby
> (Neo4j Java driver, which Memgraph officially supports). The same tagged suite
> passes identically on each. Memgraph advertises itself as *"Neo4j/v5.11.0
> compatible"* and this driver negotiates **Bolt 5.x** with it.

## Connecting

Use the **`bolt://`** scheme (not `neo4j://` — see gaps). Memgraph ships with
authentication disabled by default, so use `AuthTokens.none`:

```ruby
require 'neo4j/driver'

driver = Neo4j::Driver::GraphDatabase.driver(
  'bolt://localhost:7687',
  Neo4j::Driver::AuthTokens.none            # or .basic(user, pass) if auth is enabled
)

driver.session do |session|
  session.run('RETURN 1 AS n').single[:n]   # => 1
end
```

Do **not** pass `database: 'neo4j'` — Memgraph's default database is named
`memgraph`. Omit the database entirely, or pass `database: 'memgraph'`.

Memgraph's auth model has no explicit on/off switch: a fresh instance has **no
users and open access**, and creating the **first** user (`CREATE USER … IDENTIFIED
BY …`) flips the whole instance to **mandatory authentication for everyone**. Once
any user exists, use `AuthTokens.basic(user, pass)` — `AuthTokens.none` is then
rejected.

## What works out of the box (`bolt://`)

| Capability | Status |
|---|---|
| Connect, `AuthTokens.none`, `verify_connectivity` | ✓ |
| Bolt version negotiation | ✓ (Bolt 5.x) |
| Scalars, parameters (Integer/String/Float/List/Map), `UNWIND` | ✓ |
| Nodes, relationships, paths, labels | ✓ |
| Temporal read **and** parameter round-trip — `Date`, `LocalDateTime`, zoned `DateTime`, `Duration` | ✓ (µs precision — see gaps) |
| `Types::Point` (2D) read and round-trip | ✓ |
| `Types::Duration` parameter round-trip | ✓ (value-exact to µs) |
| Explicit transactions (`begin_transaction`) | ✓ |
| Managed transactions (`execute_read` / `execute_write`, with retry) | ✓ |
| `CALL dbms.components()` | ✓ (Memgraph implements it) |

## Known gaps (Memgraph-side, not driver bugs)

| Gap | What happens | Guidance |
|---|---|---|
| **`neo4j://` routing** | `ServiceUnavailableException: Unable to retrieve routing information` — Memgraph has no Neo4j routing-table procedure | Use `bolt://`. Memgraph's HA/replication is its own design, not Neo4j cluster routing. |
| **Default database name** | `session(database: 'neo4j')` → *unknown database "neo4j"* | Omit `database:`, or use `'memgraph'`. |
| **Bookmarks** | `session.last_bookmarks` returns an empty set after commit | Memgraph has no causal-consistency bookmarks. The driver returns an empty set (not an error) — safe to ignore. |
| **Byte-array parameters** | Memgraph errors when a `String` with `BINARY` (`.b`) encoding is sent as a parameter | Memgraph has no blob type on the Bolt wire. Avoid byte parameters. |
| **`duration()` with months** | `duration('P1M…')` → *Invalid duration string* | Cypher-dialect difference: Memgraph durations are day/time only (no month component). Month-less strings and the Bolt `Duration` struct (`months = 0`) work fine. |
| **Temporal precision** | A `Time`/`DateTime`/`Duration` carrying **sub-microsecond nanoseconds** comes back with the last three digits zeroed (e.g. `…123456789` → `…123456000`) | Memgraph stores temporal values at **microsecond** resolution; Neo4j keeps full **nanosecond** resolution. Values round-trip exactly at µs precision; only the sub-µs remainder is lost. Memgraph's parser also rejects nanosecond-precision string literals (`localtime('12:00:00.123456789')` → *Extra characters…*). |
| **`datetime({epochMillis: …})`** | Memgraph's `datetime()` has no `epochMillis` / `epochSeconds` / `nanosecond` construction keys | Construct from an ISO string or the Bolt temporal struct instead. |
| **Single-digit date components** | `localdatetime('2018-1-1T…')` → parse error | Memgraph requires zero-padded `YYYY-MM-DD`; Neo4j is lenient. Zero-pad and it works on both. |

These are all detected cleanly — a clear exception, a benign empty result, or a
documented precision truncation — so application code fails fast (or degrades
predictably) rather than silently misbehaving.

## How it's tested

Memgraph is treated as **another target of the existing shared suite** — the same
way that suite already runs against the MRI and JRuby flavors — rather than a
parallel set of Memgraph-specific specs. The whole `spec/shared/**` suite runs
against Memgraph unchanged; the handful of examples that assert Neo4j-only
behaviour are tagged and skipped.

**The `memgraph: false` tag.** Examples exercising a documented gap carry
`memgraph: false` metadata with a one-line reason, e.g.:

```ruby
context 'when bytes', memgraph: false do # Memgraph has no Bolt byte-array type
```

`spec/spec_helper.rb` excludes them only when the suite targets Memgraph
(`config.filter_run_excluding memgraph: false if memgraph?`), mirroring the
existing `auth: :none` / `csv:` conditional excludes. Against Neo4j the tag is
inert — every example still runs. Currently **~477 of ~578** shared examples run
against Memgraph — **identically on both flavors** (MRI and JRuby); the ~100
tagged ones cover the gaps in the table above (routing, bookmarks, multi-database,
byte params, duration/temporal precision, summary/plan/profile shape, auth) plus
error-*text* differences: Memgraph's error **class** matches Neo4j's (see below),
but its message/code strings differ, so assertions like `raise_error(…, "/ by
zero")` don't hold. Where a gap is a format artifact rather than a hard limitation
(single-digit dates, sub-µs precision), the tagged example keeps a parallel that
*does* run on Memgraph, so coverage isn't simply dropped.

**Error-class parity.** Memgraph sends its own status codes (e.g.
`Memgraph.ClientError.MemgraphError`). The MRI driver classifies an error by its
**classification segment** — the second dotted part — matching the Java driver's
`ErrorUtil`, rather than requiring a literal `Neo.` prefix. So both flavors raise
the same `ClientException` / `TransientException` / `DatabaseException` for a given
Memgraph error, and the tagged set is identical on MRI and JRuby.

**Connecting the suite to Memgraph** is env-driven (`spec/shared/support/driver_helper.rb`):

| Env var | Value | Why |
|---|---|---|
| `TEST_MEMGRAPH` | `1` | Activates the `memgraph: false` exclusion |
| `TEST_NEO4J_DATABASE` | `memgraph` | Memgraph's default database (there is no `neo4j` db) |
| `NEO4J_VERSION` | `5.11.0` | Memgraph's advertised Neo4j-compat level; feeds version-gated specs |

The suite runs **with authentication on** (basic `neo4j`/`password`, the
`driver_helper` default) so the auth path is exercised the same way as against
Neo4j. Memgraph enables auth as soon as a user exists, and the `MEMGRAPH_USER` /
`MEMGRAPH_PASSWORD` env vars create that user at startup — so the container comes
up with auth already on:

```bash
docker run -d -p 7687:7687 \
  -e MEMGRAPH_USER=neo4j -e MEMGRAPH_PASSWORD=password memgraph/memgraph:3.12.0
TEST_MEMGRAPH=1 TEST_NEO4J_DATABASE=memgraph NEO4J_VERSION=5.11.0 bundle exec rspec
```

## Continuous integration

The Memgraph leg is a job in `.github/workflows/specs.yml` — the *same* workflow
and the *same* `bundle exec rspec` invocation as the Neo4j matrix, just pointed at
a Memgraph service container with the env vars above:

- **`rspec-memgraph`** starts a pinned `memgraph/memgraph:3.12.0` service
  container (with `MEMGRAPH_USER`/`MEMGRAPH_PASSWORD` set, so it comes up with auth
  on), waits until Memgraph is query-ready, and runs `bundle exec rspec` with
  `TEST_MEMGRAPH=1` (+ `memgraph` database, basic auth). No separate spec file, no
  separate workflow — it reuses the entire shared suite. It runs as a **matrix
  over both flavors**: latest CRuby (MRI pure-Ruby Bolt) and latest JRuby (Java
  driver).
- **`memgraph-success`** is a version-free aggregator gate (mirroring
  `rspec-success`) so the branch-protection ruleset can require a stable name that
  doesn't embed the Memgraph image version.

Notes:

- **CRuby leg is fully green and gates.** The JRuby leg is non-blocking and shows
  **two** tests red — the Java driver's connection **re-auth** (`verify_authentication`)
  and its handling of a **cancelled failing stream** behave differently against
  Memgraph than the pure-Ruby impl does (both pass on CRuby+Memgraph and on both
  flavors against Neo4j). These reflect the Java driver's own behavior, which we
  don't override, so they're left as known JRuby×Memgraph differences.
- **Non-gating until promoted.** `memgraph-success` is not yet in the ruleset;
  require it once the lane has been stable for a while.
- **Image is pinned** to `memgraph/memgraph:3.12.0` so a Memgraph release can't
  silently change the result; bump it deliberately after re-validating.
