# MRI Bolt::Connection — pipeline-first refactor

Status: **slice 1 implemented** (2026-06-19). The reactor + reader/writer
fibers, pipelined synchronous HELLO+LOGON, recv-timeout machinery (`IO#timeout` →
`ConnectionReadTimeoutException`), NOOP handling, failure fan-out and
acquisition-deadline bounding (handshake + ROUTE) are in. The recv-timeout
machinery is wired but the `ConfHint:connection.recv_timeout_seconds` flag is
**not advertised yet** — advertising it adds a new feature surface, which is out
of scope for a refactor slice; it's flipped in the slice that wraps up the
recv-timeout/liveness cluster. Validated against the full rust-boltstub stub
suite on MRI: **zero regressions vs the pre-refactor baseline**, +6 fixes (incl.
the NOOP / handshake-encompass / router-ip tests). Slices 2–4 (MinimalResets,
router liveness, the pipelining optimizations) remain. The why and the
symptom→root map are in "The problem" below; `DECISIONS.md` has the dated
decision and the slice-1 implementation notes.

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

## Target model — driver-owned reactor, fiber readers, bridged callers

Decided 2026-06-19 (with the user) and **empirically validated** on Ruby 3.4.9 /
async 2.39.0 (`docs/async_spike.rb`). Reads and writes are fully independent —
not a pull-driven degradation — in every host.

**The driver owns one `Async` reactor thread.** All connection IO (read *and*
write) runs as fibers on it. Each connection has a long-lived **reader fiber**
that drains responses for the whole connection lifetime — including while the
connection sits idle in the pool, so a server keepalive/close is noticed
independently of any request.

The spine is a FIFO queue of `(message, response handler)` pairs:

- `send_message` enqueues `(message, handler)` and returns a **result mailbox**
  — concretely a stdlib `Thread::Queue` (one-shot) or `Mutex`+`ConditionVariable`,
  *not* `concurrent-ruby`'s `Future`. These are the Ruby-3.2 scheduler-aware
  primitives: they block a plain caller thread *and* yield a fiber under a
  scheduler, so the same handle works in both worlds (`Async::Variable`/
  `Async::Condition` are the in-reactor idiom, but can't be awaited from a
  non-scheduler caller thread, which is why the mailbox is stdlib).
- The reader fiber loops: read one response, pop the front handler, complete its
  mailbox (`SUCCESS` / `FAILURE` / `IGNORED`) or feed a `RECORD` into the owning
  `Result`'s buffer. Bolt responses arrive in request order → front-of-queue
  dispatch is correct.
- A caller blocks on its mailbox when it needs the value.

**Callers bridge in via scheduler-aware primitives** (`Queue` / `Mutex` /
`ConditionVariable`, made fiber-aware in Ruby 3.2):

- Under a **Fiber scheduler** (Falcon, or any `Async {}`): the caller fiber
  yields while waiting → the host reactor runs other requests. Async for free.
- **Without** a scheduler (Puma threads, bare scripts): the caller thread
  blocks on the mailbox; the driver's reactor completes it cross-thread — the
  scheduler's `unblock` hook is thread-safe (validated: a non-scheduler thread
  woke a reactor fiber parked on a `Thread::Queue` and got a result back).

**Reuse an ambient reactor when one is already running.** "Driver-owned"
describes the *default* — the owned background reactor for sync/Puma callers. But
when the driver is used from inside an existing Async reactor (Falcon, or any
`Async {}`), spinning up a *second* reactor thread is wasteful and forces a
cross-thread hop on every call. So `Bolt::Reactor#run` checks
`Async::Task.current?`: if there is an ambient reactor it runs the connection's
reader/writer fibers there — as **`transient`** tasks, so a perpetual reader
never keeps a one-shot `Async {}` block from returning and the fibers are torn
down with the reactor. Only when there is no ambient reactor does it lazily
start the owned background thread. Net effect: under Falcon the calling fiber and
the IO fibers share one reactor (truly "async for free", no thread hop); under
Puma/sync the owned reactor does the work and callers bridge in cross-thread.

The reader fiber is long-lived and a fiber can't move between threads
(`FiberError`), so the ambient path assumes the driver is confined to a single,
long-lived reactor — the Falcon-per-process norm. Sharing one driver across
several independent reactors on different threads must use the owned reactor;
don't first-use such a driver from inside an ephemeral `Async {}` on a worker
thread. (Scaling is still "more processes", each with its own driver+reactor.)

### Why driver-owned (not per-caller) reactor

- **Fibers can't cross threads** (`FiberError: fiber called across threads`,
  verified). Connections are pooled and borrowed by sessions on different
  threads/fibers. A reader fiber pinned to caller-thread A's reactor cannot be
  driven when thread B borrows that connection. Per-caller reactors would force
  per-thread pools (no sharing → up to N×threads more server connections, and a
  long-lived reactor per thread anyway). One driver-owned reactor keeps a single
  shared pool coherent.
- **TLS-safe.** A single reactor thread serializes each socket's read+write
  cooperatively → never a concurrent `SSL_read`/`SSL_write` on one `SSLSocket`
  (which OpenSSL is not safe for). And `SSLSocket#read` *yields* under the
  scheduler (validated: a 1s TLS read let other fibers run), so it doesn't
  freeze the reactor.

### Scalability

One reactor per driver **per process** is the right granularity for MRI, not a
bottleneck: the GVL already serializes all Ruby parsing onto one core, so a
thread-per-connection model is single-core for deserialization too — the reactor
just centralizes that already-serialized work with *less* overhead (no GVL
contention, cheap fiber switches, one `epoll`/`kqueue` wait vs N blocked
threads). Multiplexing ~100 pooled sockets is trivial for an event loop. Scale
past one core the standard Ruby way — **more processes** (Puma/Falcon workers,
each with its own driver+reactor); more reactor *threads* in one process
wouldn't help (GVL). Discipline: keep CPU-heavy/user code *off* the reactor
(hand records back to the caller); the reactor does only IO + bounded per-message
parse + mailbox completion.

### Considerations (the substance of slice 1)

- **Thread-safety** of the handler queue and connection state (the cross-thread
  bridge is the only multi-thread surface; everything else is reactor-local).
- **RECORD streaming:** the reader feeds records into a buffer the consumer reads
  from; backpressure (PULL `n`) is the reader's concern.
- **Failure fan-out:** a dead socket / read timeout resolves **all** pending mailboxes
  and marks the connection dead.
- **Clean shutdown:** closing a connection / stopping the driver must unblock the
  reader and tear down the reactor thread without leaking.
- **recv-timeout:** `IO#timeout` (scheduler-aware) on the reader; timeout while
  reads are pending fails them, while idle it is a keepalive signal.

## Slice sequencing (each its own validation pass)

1. **Reactor + reader-fiber + handler-queue + mailbox machinery, proven on HELLO+LOGON.**
   This is the foundation, not a localized reorder: stand up the per-connection
   driver-owned reactor, the per-connection reader fiber, the mutex-guarded
   `(message, handler)` FIFO, result mailboxes, RECORD
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
  only when its whole cluster genuinely passes.
- Validate every slice against the testkit stub suite locally with the **rust**
  boltstub on the **MRI** flavor before expanding (ruby-3.4.9 via rvm; see
  `DEVELOPMENT.md` and the `bin/run-testkit` header). The full suite is
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
