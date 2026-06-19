# MRI Bolt::Connection — pipeline-first refactor

Status: **proposed** (2026-06-19). Kickoff design for a fresh session. See the
`mri-needs-pipelined-connection` memory for the why and the symptom→root map,
and `DECISIONS.md` for the dated decision.

## The problem

MRI's `Bolt::Connection` is **synchronous send-then-read**: nearly every call
site does `send_message(x); flush; fetch_response`. Outbound bytes are written
per message (`send_message` → `write_chunk`), and `@response_queue << :pending`
already tracks each in-flight response — but the *reads* happen eagerly, one
right after each send. The Bolt protocol and the testkit conformance suite
assume the opposite: a **pipelined** peer that can send a batch of messages and
read the responses lazily, in order.

Every hard feature that has stalled traces to this one gap:

- **recv-timeout (Liveness):** `liveness_check_recv_timeout.script` is
  `C: HELLO  C: LOGON  S: SUCCESS  S: SUCCESS` — the stub answers only after it
  has **both** messages. MRI sends HELLO and *reads* before sending LOGON →
  deadlock.
- **MinimalResets / the 5 `drop_connections` tests:** MRI's only reset is a
  synchronous RESET round-trip. Eager reset-on-release timed out the whole stub
  suite. Java marks the connection dirty and **pipelines** the RESET ahead of
  the next use, reading its reply lazily.
- **Optimization:PullPipelining (~100 routing tests):** only works by accident
  today — `Session#run`/`Transaction#run` queue RUN+PULL then flush. The one
  place the pipelined shape leaks through, undeclared.
- **Optimization:AuthPipelining / ExecuteQueryPipelining** (`ja`, MRI blank):
  same root.

## Current model (what exists)

- `send_message(msg)`: packs + writes the chunk to `@socket`, pushes `:pending`
  onto `@response_queue`.
- `flush`: flushes the socket write buffer.
- `fetch_response`: reads one response, pops one `:pending`.
- `send_all(*msgs)`: sends each + one flush (building block, already present).
- Call sites interleave: `send X; flush; read X; send Y; flush; read Y`.

So the **spine** (an ordered queue of in-flight responses) is already there. The
refactor is a *discipline change* at the call sites + the handshake, not a
ground-up rewrite.

## Target model — fully independent reads (reader thread, from day one)

Decision (2026-06-19, with the user): **true independence, not a pull-driven
interim.** A pull-driven "read when the caller needs it" step would just be more
deferred debt. So reads run on their own loop from the start.

The spine is a FIFO queue of `(message, response handler)` pairs:

- `send_message` enqueues `(message, handler)` under a mutex, writes the bytes,
  and returns a **future**; the writer may `flush` at any time.
- A **reader thread per connection** loops: read one response, pop the front
  handler, and either complete its future (`SUCCESS` / `FAILURE` / `IGNORED`) or
  feed a `RECORD` into the owning `Result`'s buffer. Bolt guarantees responses
  arrive in request order, so front-of-queue dispatch is correct.
- A caller that needs a value blocks on its future (a condition variable the
  reader signals). Sends and reads are otherwise independent.

**Thread, not fiber.** The driver is thread-based today (sessions, pool, auth-
epoch mutexes); a reader thread slots in incrementally (Ruby frees the GVL on
blocking socket reads). Fibers would need a Fiber scheduler threaded through the
whole call stack — an all-or-nothing async-runtime shift. (Open if we ever adopt
async-gem-style fibers wholesale.)

This directly yields the stalled features: HELLO+LOGON pipeline naturally;
release marks the connection **dirty** and pipelines a RESET ahead of next use
(real MinimalResets); RUN+PULL pipelining is formalized (PullPipelining), then
AuthPipelining / ExecuteQueryPipelining. A FAILURE makes the server IGNORE the
rest — each trailing handler simply sees its `IGNORED`, which the handler model
absorbs cleanly.

### Considerations the reader thread brings (the substance of slice 1)

- **Thread-safety** of the handler queue (`Thread::Queue` / `Monitor`) and
  connection state.
- **RECORD streaming:** the reader feeds records into a thread-safe buffer on the
  `Result`; the consumer iterating the result blocks on that buffer.
  Backpressure (PULL `n`) is the reader's concern.
- **Failure fan-out:** a dead socket or read timeout fails **all** pending
  futures and marks the connection dead — not only the one in flight.
- **Clean shutdown:** closing the connection must unblock the reader's blocking
  read (close the socket / signal) so the thread exits without leaking.
- **Pool semantics stay simple:** a connection is held by one session at a time,
  so the reader serves a single pipeline — no multi-session concurrency on one
  connection.
- **recv-timeout:** the reader applies the `connection.recv_timeout_seconds`
  socket read timeout (verified to work via `IO#timeout`); a timeout while reads
  are pending fails them, while idle it is benign / a keepalive signal.

## Slice sequencing (each its own validation pass)

1. **Reader-thread + handler-queue + futures machinery, proven on HELLO+LOGON.**
   This is the foundation, not a localized reorder: stand up the per-connection
   reader thread, the mutex-guarded `(message, handler)` FIFO, futures, RECORD
   buffering, failure fan-out and clean shutdown. Exercise it first on the
   handshake (send HELLO+LOGON, then the reader drains both) and on a basic
   RUN/PULL. Combine with the `connection.recv_timeout_seconds` socket timeout to
   close the recv-timeout liveness test. Re-run the **full** stub suite — this
   touches every operation, so the regression bar is the whole suite, green.
2. **Pipelined dirty-connection RESET** → real `OPTIMIZATION:MinimalResets`.
   MRI already passes the two MinimalResets *gate* tests (`test_no_reset_on_
   clean_connection`, `test_exactly_one_reset_on_failure`) for clean connections;
   the work is aligning the **error/retry path** so advertising MinimalResets
   doesn't break `test_should_not_retry_non_retryable_tx_failures` (×2). Then
   advertise it → the 5 `drop_connections` tests pass (they need the metrics WIP
   already on this branch).
3. **Router liveness** (the 2 `test_timeout*` routing tests) — a *narrow*
   trigger, NOT the blanket per-op home-db re-route that regressed
   `test_should_read_..._default_db`. Guard with that default-db test.
4. **Pipelining optimizations** — PullPipelining (~100), then AuthPipelining /
   ExecuteQueryPipelining, fall out of the formalized model.

## Constraints / guardrails

- Don't flip `get_features.rb` flags to grab skipped tests; advertise a flag
  only when its whole cluster genuinely passes (`no-new-feature-advertising`).
- Validate every slice against the testkit stub suite locally with the **rust**
  boltstub on the **MRI** flavor before expanding (`local-tls-testing` /
  `local-boltstub-debug-loop` memories; ruby-3.4.9 via rvm). The full suite is
  the regression guard — eager reset-on-release proved a per-release round-trip
  is unacceptable (it timed the suite out).
- Already done and parked on `fix/mri-liveness-check-routing`:
  `Driver#metrics` + per-address `idle`/`in_use` (commit "wip(mri):
  connection-pool metrics infrastructure"). Reusable by slice 2.

## Validation loop

```
TEST_NEO4J_URL=bolt://localhost:7687  # for integration; stub needs no server
TEST_RUSTY_STUB=true \
  bin/run-testkit tests.stub.<module>   # rust boltstub, MRI flavor (rvm ruby-3.4.9)
bundle exec rspec spec/mri spec/shared/neo4j
```
