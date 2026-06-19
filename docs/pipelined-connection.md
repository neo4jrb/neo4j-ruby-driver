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

## Target model

Pipeline-first: **flush a batch of outbound messages, then drain their responses
in order, lazily** — read only when a result is actually needed.

- Handshake sends HELLO **and** LOGON before reading, then drains both responses.
- A connection returned to the pool is marked **dirty**; the RESET is pipelined
  ahead of its next message rather than a synchronous round-trip on release.
- `Result`/`Transaction` already queue RUN+PULL; formalize that as the norm and
  expose it (PullPipelining), then AuthPipelining / ExecuteQueryPipelining.
- Errors: when a pipelined message FAILs, the server IGNOREs the rest — the
  response drainer must consume the IGNOREDs in order and surface the first
  FAILURE (this is the part to get right and test hard).

A reader thread/fiber (true async, for idle keepalive NOOP reads and
recv-timeout while idle) is a **clean later layer** on top — not needed for the
first slices.

## Slice sequencing (each its own validation pass)

1. **HELLO+LOGON pipelining** — smallest real slice. `perform_hello` +
   `perform_post_hello` send both, then read both. Directly unblocks the
   recv-timeout liveness test (combine with `@socket.timeout =` from the
   `connection.recv_timeout_seconds` HELLO hint — the socket-timeout mechanism
   is already verified to work via `IO#timeout`). Re-run the full stub suite.
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
