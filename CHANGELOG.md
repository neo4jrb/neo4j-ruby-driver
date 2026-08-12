# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The gem version tracks the [neo4j-java-driver](https://github.com/neo4j/neo4j-java-driver)
version it targets, with a Ruby-side pre-release suffix (e.g. `6.2.1-beta.1`).

This changelog was started partway through the project's life; for detailed
per-change history before it, see the [git log](../../commits/main) and the
merged pull requests. Entries below accumulate under **[Unreleased]** and are
moved under a version heading when a release is cut.

## [Unreleased]

### Added
- **Bolt 6.1** with the native **UUID** type, surfaced as a flavour-agnostic
  value: `java.util.UUID` on JRuby, an opaque `Neo4j::Driver::Types::UUID`
  (`from_string`/`to_s`, value-equal, immutable) on MRI.
- **Optional profile stats** — an absent PROFILE stat is omitted rather than
  reported as `0` (JRuby reads the 6.2 `QueryProfile` presence-aware getters).

### Changed
- The gem now targets **neo4j-java-driver 6.2.x** (JRuby).
- Development dependencies consolidated into a single source and `rspec-its`
  bumped to `2.0`.

### Removed
- **JRuby: the unused async API** (`async_session`, `run_async`, `next_async`,
  `close_async`, and the `AsyncConverter` bridge) — it had no callers. This
  drops **`concurrent-ruby-edge`** as a JRuby runtime dependency.

### Fixed
- **License** metadata corrected to **MIT** (the gemspec claimed `Apache-2.0`
  and no `LICENSE.txt` was present); the project has always been MIT.

---

## Project capabilities (as of the current pre-release line)

Rather than reconstruct every pre-changelog release, this is a snapshot of what
the two implementations support today. Both present the same public Ruby API.

- **Protocol**: Bolt 3.0 through 6.1, handshake-manifest negotiation, UTC
  datetime patch.
- **Type system**: nodes, relationships, paths; full temporal types; spatial
  points; duration; UUID; and a forward-compatible `UnsupportedType`.
- **Sessions & transactions**: auto-commit, explicit (default-rollback), and
  managed read/write with retry; causal bookmarks.
- **Auth**: basic, bearer, Kerberos, custom, and managed auth-token managers,
  with re-authentication; per-session and per-`execute_query` auth.
- **Routing**: cluster routing, home-database resolution and caching.
- **Security**: TLS 1.2/1.3, `+s`/`+ssc` schemes, and mutual-TLS client
  certificates.
- **More**: notifications config, GQL status objects, query telemetry,
  connection-acquisition timeouts, and a range of wire optimisations
  (pull/auth/execute-query pipelining, eager transaction begin, …).

Coverage is verified against the shared driver
[testkit](https://github.com/neo4j-drivers/testkit) conformance suite on both
implementations.
