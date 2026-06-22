# Decision Log

Chronological record of architectural choices. Newest entries at the
bottom. Keep entries short — the source is the source of truth for
code; this log captures the *why*.

## 2026-04-22 — `Session#run` parameters/config split

`def run(query, parameters = {}, config = {})` — explicit split rather than
merged kwargs. Lets the same key appear in both (e.g.
`session.run(q, { metadata: 'param' }, metadata: { config: true })`).
Mirrors `execute_read/write`, which take `timeout` and `metadata` explicitly.

## 2026-04-22 — Timeout units: seconds in API, milliseconds on the wire

User-facing API accepts seconds (or `ActiveSupport::Duration`). Conversion to
ms happens in `timeout_to_milliseconds` before sending over Bolt. Matches
Ruby's `sleep(60)` convention.

## 2026-04-22 — Bookmarks replaced, not accumulated

`session.last_bookmarks` returns a `Set` of 0 or 1. Each committed transaction
generates one bookmark that replaces the previous. Unsuccessful ops (rollback,
failure, auto-commit) don't update it. Matches Java driver.

## 2026-04-22 — `last_bookmarks` returns unfrozen Set

Dropped `.dup.freeze` from the accessor. No reason to special-case bookmarks
when no other returned object is protected this way. Trust the caller.

## 2026-04-22 — Zeitwerk one-class-per-file

Refactor to strict Zeitwerk conventions. Nested classes are allowed when
they're genuine implementation details (`Path::Segment`, `Summary::Query`).
Namespace modules are autovivified from directory names — no
`<namespace>.rb` stubs that just declare `module Foo; end`.

## 2026-04-23 — Default-rollback for explicit block `begin_transaction`

`session.begin_transaction { |tx| ... }` rolls back on clean block exit
unless the user calls `tx.commit`. Managed transactions
(`execute_read/write`) still auto-commit on success. Matches the Java
driver's try-with-resources semantics.

## 2026-04-23 — `Result` state: `@consumed` vs `@discarded`

Two distinct flags:

- `@consumed` — stream drained from the wire (natural end, success or failure).
- `@discarded` — records explicitly released (user called `.consume`, or the
  owning session was closed); subsequent access raises `ResultConsumedException`.

After iteration via each/map/to_a: `@consumed=true`, `@discarded=false` —
subsequent `to_a` returns empty, not raise. After explicit `.consume` or
session close: `@discarded=true` — access raises.

Separately added `Result#buffer` (not user-facing): the driver calls it
internally when reusing a connection for a new query, so the prior
result's records are pulled into memory and remain accessible through the
user's existing reference.

## 2026-04-23 — Connection pooling via `connection_pool` gem

Use `ConnectionPool::TimedStack` — the gem's lower-level primitive —
not the top-level `ConnectionPool#checkout`, which caches per-thread and
would let multiple Sessions in the same thread share a connection and
step on each other's server-side transaction state.

Requires Ruby ≥ 3.2 (the 3.0 release of `connection_pool` dropped earlier
Rubies), so `required_ruby_version` is bumped to `>= 3.2.0`.

## 2026-04-23 — DateTime LOCAL encoding for signatures 0x46 / 0x66

Neo4j encodes `epoch_seconds` as wall-clock time treated as if it were
UTC (not the true UTC instant). The driver applies the conversion at the
boundary:

- Pack: `epoch_seconds = value.to_i + value.utc_offset`.
- Hydrate 0x46: `Time.at(seconds - offset).getlocal(offset)`.
- Hydrate 0x66: `tz.tzinfo.local_to_utc(wall_clock)` so the zone's *actual*
  offset at that instant is applied. A fixed `2 * tz.utc_offset` formula
  only happens to work in summer.

TimeWithZone values with a non-offset-shaped zone name are packed as 0x66
(preserves zone through Cypher equality); everything else as 0x46.

## 2026-04-23 — All requires in the gem entry

Stdlib and gem `require`s all live in `lib/neo4j/driver.rb`. Scattered
requires make load order depend on which internal file Zeitwerk touches
first, and turn touching an internal class into an implicit load-time
side effect. `require` is already idempotent, so `unless defined?(X)`
guards are pointless.

## 2026-04-27 — Ruby 3.4+ minimum

Bumped `required_ruby_version` from `>= 3.2.0` to `>= 3.4.0` to use
the `it` implicit block parameter in pipeline-style code (e.g.
`timeout&.then { (it.to_f * 1000).round }`). CI workflows updated
to Ruby 3.4 in lockstep. Two version bumps in three days is fine
while we're pre-1.0; once the API stabilises we'll be more
conservative about minimum-Ruby moves.

## 2026-06-05 — Connection-pool metrics deferred (shaded-jar ABI clash)

`get_connection_pool_metrics` (testkit) / `Driver#metrics` stays
unimplemented. The gem bundles the **shaded** `neo4j-java-driver-all`
uber jar (relocates bolt-connection → `…internal.shaded.bolt.connection`).
The `neo4j-java-driver-observation-metrics` module is built against the
**unshaded** driver, so its `boltExchange(…, org.neo4j.bolt.connection
.BoltProtocolVersion, …)` doesn't satisfy the all-jar's
`DriverObservationProvider.boltExchange(…, internal.shaded…
BoltProtocolVersion, …)` → `AbstractMethodError` on the first query.
The two jars cannot interoperate. Java sidesteps this: its testkit-backend
depends on the unshaded modular `neo4j-java-driver` + observation-metrics,
while the shaded `-all` (Maven module `bundle`) is a prod convenience
fat-jar that is *also* metrics-incompatible. We ship one jar for both
prod and testkit, and the ext layer is hardwired to shaded class names.

Skipped because it unlocks only 5 near-duplicate stub tests
(`test_should_drop_connections_failing_liveness_check` ×
v3/v4x2/v4x3/v4x4/v5x0, gated on Feature:API:Liveness.Check) at the cost
of migrating the whole JRuby ext off the shaded jar.

When the MRI metrics path is built (MRI's `Driver#pool_metrics` currently
raises NotImplementedError), keep the testkit handler shape compatible
with a *hypothetical unshaded JRuby build* too: consume a duck-typed
metrics object (`connection_pool_metrics` → items responding to
`id`/`in_use`/`idle`), and match the requested address by parsing `id`
as `"host:port-…"`, mirroring Java's `GetConnectionPoolMetrics`.

## 2026-06-19 — MRI Bolt::Connection goes pipeline-first

The synchronous send-then-read connection model is a wall: HELLO+LOGON
pipelining (recv-timeout), pipelined RESET-on-release (MinimalResets / the 5
drop_connections tests), PullPipelining/AuthPipelining/ExecuteQueryPipelining,
and the router-liveness interaction all stall on it. The earlier "async is
overengineering / YAGNI" call deferred the foundation the Bolt protocol and the
conformance suite assume; we're paying the interest now.

Decision: make `Bolt::Connection` fully read/write independent via a
**driver-owned `Async` reactor**, from day one — true independence, not a
pull-driven interim (deferred debt again). The driver owns one reactor thread;
all connection IO (read+write) runs as fibers on it; each connection has a
long-lived reader fiber that drains responses for the connection's whole life
(incl. idle in the pool). `send_message` enqueues `(message, handler)` on a FIFO
and returns a result mailbox (a stdlib scheduler-aware `Thread::Queue`/
`ConditionVariable`, not concurrent-ruby's Future); the reader fiber resolves
mailboxes (SUCCESS/FAILURE/IGNORED) / buffers RECORDs, in request order. Callers bridge in via the Ruby 3.2
scheduler-aware `Queue`/`Mutex`/`ConditionVariable`: under a Fiber scheduler
(Falcon) the caller fiber yields (async for free); without one (Puma/sync) the
caller thread blocks and the reactor resolves its mailbox cross-thread (the
scheduler's `unblock` hook is thread-safe).

Why driver-owned, not per-caller: **fibers can't cross threads** (FiberError),
but pooled connections are borrowed across threads — so a reader fiber must have
one stable home or the shared pool breaks. Single-threaded reactor IO is also
TLS-safe (no concurrent SSL_read/SSL_write). Scalable for MRI: the GVL already
serializes parsing onto one core, so the reactor centralizes already-serialized
work with less overhead than thread-per-connection; scale past one core via
processes (Falcon/Puma workers), not more reactor threads.

Empirically validated on Ruby 3.4.9 / async 2.39.0 (`docs/async_spike.rb`):
cross-thread fiber resume raises FiberError; SSLSocket#read yields under the
scheduler; a non-scheduler thread woke a reactor fiber on a Thread::Queue and got
a result back. Sequence in validated slices: (1) reactor/handler/futures
machinery proven on HELLO+LOGON + recv-timeout; (2) pipelined dirty-connection
RESET → real MinimalResets (the 5 drop_connections tests); (3) a *narrow*
router-liveness trigger; (4) PullPipelining / AuthPipelining /
ExecuteQueryPipelining. Full design: `docs/pipelined-connection.md`. Do NOT keep
nibbling symptoms — per-op home-db re-route regressed default-db reads; eager
reset-on-release timed out the suite.

## 2026-06-22 — MRI Bolt::Connection: sans-I/O core + pump (threads, not Async)

Revisits the 2026-06-19 reactor decision. The reactor made `lib/mri/` depend on
the `async` gem, which is unsupported on JRuby (no native IO_Event selector;
IO#timeout/scheduler don't fire; the reactor hangs) — forcing the mri-on-jruby
flavor to be dropped. A driver also shouldn't impose a concurrency model on the
host.

Decision (with the user; rationale in `async_vs_threads.md`): build the MRI
connection as a **sans-I/O core + pluggable pump + bounded watermark buffer**,
depending only on Ruby core + stdlib — no `async`.

- `Bolt::Wire` — sans-I/O state machine (enqueue→framed bytes; receive(bytes)→
  messages), no socket. Owns chunk framing, NOOP skipping, hydration.
- `Bolt::Connection` is the **on-demand pump** over the wire: synchronous,
  caller-thread reads via `wait_readable` + `read_nonblock` (honors a timeout
  *and* yields under a Fiber scheduler — colorless I/O). Pipelined synchronous
  HELLO+LOGON; recv-timeout + acquisition-deadline via the read timeout.
- `Bolt::RecordBuffer` (SizedQueue + hi/low watermark autopull), `Bolt::Pump`
  (background prefetch loop), `Bolt::Executor` (Thread default; `Fiber.schedule`
  when `Fiber.scheduler` present — the only mode-aware check; core interface,
  never the async gem). Prefetch is opt-in and validated by unit/spec (incl. the
  fiber path under an `Async {}` test scheduler); the default streaming path is
  on-demand.

Result: runs on threads by default (so **mri-on-jruby is restored**) and rides a
host reactor for free under a scheduler. Validated: full rust-boltstub stub
suite on CRuby ruby-3.4.9 = **zero regressions vs main**, +5 fixes (NOOP /
handshake-encompass); mri-on-jruby runs the suite without hanging.

Difference vs the reactor branch (#395): the on-demand pump doesn't read idle
pooled connections, so it can't notice a server closing/moving one until next
use — `test_should_successfully_acquire_rt_when_router_ip_changes` (which the
reactor's background reader caught). Not a regression vs main; regain it later
via the pool liveness probe or the single-selector escalation. The two designs
are parallel branches; this one is the no-async, JRuby-compatible alternative.
