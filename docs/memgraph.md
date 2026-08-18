# Memgraph compatibility

[Memgraph](https://memgraph.com) is an open-source, in-memory graph database
that speaks the **Bolt protocol** and **Cypher**, by design, so Neo4j drivers
can connect to it. This driver works against Memgraph over a direct `bolt://`
connection **with no code changes** — the gaps below are Memgraph feature/dialect
differences, not driver bugs, and the driver degrades gracefully on all of them.

> Status: **community-verified, not officially supported.** Measured against
> **Memgraph v3.12.0** with the MRI (pure-Ruby Bolt) flavor. Memgraph advertises
> itself as *"Neo4j/v5.11.0 compatible"* and this driver negotiates **Bolt 5.x**
> with it. The JRuby flavor wraps the Neo4j Java driver, which Memgraph
> officially supports, so it is expected to behave the same (confirm before
> relying on it).

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

## What works out of the box (`bolt://`)

| Capability | Status |
|---|---|
| Connect, `AuthTokens.none`, `verify_connectivity` | ✓ |
| Bolt version negotiation | ✓ (Bolt 5.x) |
| Scalars, parameters (Integer/String/Float/List/Map), `UNWIND` | ✓ |
| Nodes, relationships, paths, labels | ✓ |
| Temporal read **and** parameter round-trip — `Date`, `LocalDateTime`, zoned `DateTime`, `Duration` | ✓ |
| `Types::Point` (2D) read and round-trip | ✓ |
| `Types::Duration` parameter round-trip | ✓ (value-exact) |
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

These are all detected cleanly — a clear exception, or a benign empty result —
so application code fails fast rather than silently misbehaving.

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
inert — every example still runs. Currently **465 of 572** shared examples run
against Memgraph; the ~107 tagged ones cover the gaps in the table above (error
mapping to base `Neo4jException`, routing, bookmarks, multi-database, byte
params, duration/temporal normalization, summary/plan/profile shape, auth).

**Connecting the suite to Memgraph** is env-driven (`spec/shared/support/driver_helper.rb`):

| Env var | Value | Why |
|---|---|---|
| `TEST_MEMGRAPH` | `1` | Activates the `memgraph: false` exclusion |
| `TEST_NEO4J_AUTH` | `none` | Memgraph runs with auth disabled → `AuthTokens.none` |
| `TEST_NEO4J_DATABASE` | `memgraph` | Memgraph's default database (there is no `neo4j` db) |
| `NEO4J_VERSION` | `5.11.0` | Memgraph's advertised Neo4j-compat level; feeds version-gated specs |

Run it locally against a Memgraph container:

```bash
docker run -d -p 7687:7687 memgraph/memgraph
TEST_MEMGRAPH=1 TEST_NEO4J_AUTH=none TEST_NEO4J_DATABASE=memgraph \
  NEO4J_VERSION=5.11.0 bundle exec rspec
```

## Continuous integration

The Memgraph leg is a job in `.github/workflows/specs.yml` — the *same* workflow
and the *same* `bundle exec rspec` invocation as the Neo4j matrix, just pointed at
a Memgraph service container with the env vars above:

- **`rspec-memgraph`** starts a `memgraph/memgraph` service container, waits for
  the Bolt port, and runs `bundle exec rspec` with `TEST_MEMGRAPH=1` (+ auth-none,
  `memgraph` database). No separate spec file, no separate workflow — it reuses the
  entire shared suite.
- **`memgraph-success`** is a version-free aggregator gate (mirroring
  `rspec-success`) so the branch-protection ruleset can require a stable name that
  doesn't embed the Memgraph image version.

Notes:

- **MRI flavor only** to start — it's the pure-Ruby Bolt implementation, so it's
  the direct test of wire compatibility. A JRuby leg (Java-driver path) can follow.
- **Non-gating until promoted.** `memgraph-success` is not yet in the ruleset;
  require it once the lane has been stable for a while.
- **Pin the image** (`memgraph/memgraph:<version>`) once the baseline is
  established, so a Memgraph release can't silently change the result.
