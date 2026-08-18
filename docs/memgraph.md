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

## Continuous integration (sketch)

Because the full `spec/shared/integration/` suite includes Neo4j-specific
behaviour (routing, bookmarks, multi-database, byte parameters), a Memgraph lane
should run a **curated compatibility subset**, not the whole suite. Two moving
parts:

**1. A dedicated compatibility spec** — `spec/memgraph/compatibility_spec.rb` —
covering the "works out of the box" matrix and asserting the gaps behave as
documented (e.g. `neo4j://` raises `ServiceUnavailableException`, bookmarks are
empty). It connects with Memgraph-appropriate config (`bolt://`,
`AuthTokens.none`, no hardcoded database) rather than reusing the Neo4j
`spec_helper` defaults.

**2. A workflow** — `.github/workflows/memgraph.yml` — non-gating at first
(informational, like other incubating lanes), promoted to required once green:

```yaml
name: Memgraph compatibility

on:
  push:
    branches: [main]
    paths-ignore: ['**/*.md', 'lib/shared/neo4j/driver/version.rb']
  pull_request:
    paths-ignore: ['**/*.md', 'lib/shared/neo4j/driver/version.rb']

jobs:
  memgraph:
    name: memgraph-compat
    runs-on: ubuntu-latest
    services:
      memgraph:
        image: memgraph/memgraph:latest        # pin a version once stabilised
        ports:
          - 7687:7687
        # Memgraph has no built-in Docker healthcheck; the step below waits.

    env:
      TEST_MEMGRAPH_URL: bolt://localhost:7687

    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4'                   # MRI flavor (pure-Ruby Bolt)
          bundler-cache: true
      - name: Wait for Bolt
        run: |
          for i in $(seq 1 30); do
            (echo > /dev/tcp/localhost/7687) >/dev/null 2>&1 && exit 0
            sleep 2
          done
          echo "::error::Memgraph bolt port never opened"; exit 1
      - name: Run Memgraph compatibility spec
        run: bundle exec rspec spec/memgraph
```

Notes:

- **MRI flavor only** to start — it's the pure-Ruby Bolt implementation, so it's
  the direct test of wire compatibility. Add a JRuby leg later to cover the
  Java-driver path.
- **Version-stable gate.** If this becomes a required check, add a
  `memgraph-success` aggregator job (see `specs.yml`) so the ruleset requires a
  name that doesn't embed the Memgraph version.
- **Pin the image** (`memgraph/memgraph:<version>`) once the baseline is
  established, so a Memgraph release can't silently change the result.
