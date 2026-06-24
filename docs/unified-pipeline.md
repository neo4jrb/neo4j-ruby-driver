# MRI Bolt::Connection — one async request/response pipeline

Status: **design** (2026-06-23). Successor design to `docs/sans-io-pump.md`
(shipped as #396 + #397). Same goals — pure Ruby core + stdlib, colorless I/O,
no `async` gem, threads by default / fibers for free — but it removes the
**synchronous-on-demand vs. asynchronous-prefetch split** by making *every*
request/response flow through one pipeline.

## Why change what we just shipped

#396/#397 left two ways to move bytes over a connection:

- **On-demand** (`Connection#fetch_response`): the caller thread reads the socket
  when it needs the next reply. Synchronous.
- **Prefetch** (`Bolt::Pump` on `Bolt::Executor`): a background thread/fiber
  reads ahead into a `RecordBuffer`. Asynchronous.

They share the wire's routing (`Bolt::Wire` already holds a FIFO of
`(message, handler)` and dispatches each decoded reply to the handler at the
front), but they are *two separate mechanisms for turning the same crank*, and
they don't compose:

- The pump claims the connection as **sole reader/writer**, so a second result
  can't be active while it runs — which is why qid-multiplexing "fights" it (see
  `sans-io-pump.md` discussion + the `tx_run` `prevent_pull_*` / `iteration`
  `test_nested` gaps).
- `RecordSource#pull` hardwires `qid: -1` ("the latest result"), valid only when
  there is exactly one open stream.
- The split forces a mode decision (`Result#promote`, `Executor.reactor?`) and
  per-mode lifecycle code.

The routing is already uniform. Only the *driving* is split. Unify the driving
and on-demand, prefetch, and multiplexing all collapse into one model — and the
sibling-result termination cases fall out for free.

## The model: futures + a colorless pump step

Promote the wire's per-request handler to a **completion** (a fulfillable value)
and give the connection three primitives:

1. `enqueue(message) -> completion` — frame the request into the wire's outbound
   buffer and push its handler+completion onto the FIFO. (The wire already does
   the FIFO; this just hands back a completion.) A request is "in flight" the
   moment it's enqueued; nothing blocks here.
2. `advance` — **one pump step**: read available bytes, let the wire decode them,
   dispatch each decoded reply to its FIFO handler (which fulfils the owning
   completion on a terminal: SUCCESS/FAILURE/IGNORED). Colorless: its
   `wait_readable` blocks a real thread without a scheduler and yields a fiber
   under one (exactly today's `fill_inbox`).
3. `await(completion)` — block (colorlessly) until the connection's reader
   fulfils *this* completion, then return its value (or raise its stored error).
   For a record stream the consumer instead blocks on the result's `RecordBuffer`
   (`shift`), which the reader fills.

The connection runs a **dedicated reader** (next section) that is the sole caller
of `advance`; callers only ever `enqueue` and then block on a completion or a
buffer. "Synchronous" is just `enqueue(msg).then { await(it) }`. Every request is
async; `await`/`shift` are the thin, colorless blocking layer on top. No `async`
gem; the only concurrency primitives are stdlib `Queue`/`Mutex`/
`ConditionVariable`, which are scheduler-aware.

### One dedicated reader per active connection

Responses are strictly ordered per socket, so there is exactly **one reader**.
Rather than have whichever caller is waiting drive the socket (a leader/follower
hand-off that also only ever pulls when someone awaits), the connection owns a
**dedicated reader** for the duration of its active use. The reader loops
`advance`: read bytes → wire decodes → dispatch each reply to its FIFO handler,
which either fulfils a completion (RUN/BEGIN/COMMIT/RESET/ROUTE) or pushes a
record into the owning result's `RecordBuffer`. Callers never touch the socket;
they block on their completion or buffer.

This keeps **watermark-driven prefetch**: the reader fills each result's buffer
toward its high-water mark ahead of demand, pauses that result's `PULL`s when it
is full, and resumes when the consumer drains past the low-water mark — so the
server fetch + decode overlap the consumer's own work. (The eager **first**
`PULL` always rides with `RUN`; only `PULL` #2+ are watermark-gated — see
*How the three behaviours collapse*.) Because there is exactly one reader and
callers only consume buffers, there is **no leader/follower hand-off** and no
thundering herd — the reader is just the #397 pump generalised from one stream to
all of the connection's active results.

This is the #395 reactor's "reader + handler FIFO + mailboxes" shape — but
colorless (no `async` gem; the executor is a thread or a fiber, chosen to match
the host — see *Connection & reader lifecycle*), which is the part that made
#395 unusable on JRuby.

### Failure fan-out

`advance` hitting EOF / a socket error, or a `RESET`-worthy server state, marks
the connection broken and **fulfils every outstanding completion with the
error** — not just the one at the FIFO front. Two payoffs:

- A dead connection wakes *all* waiters (no one hangs on a completion that will
  never arrive).
- It is exactly the mechanism the sibling-result termination cases need: when
  one result's PULL fails, every other open result on that transaction has its
  completion failed, so its next `await` raises the terminating error — no
  special cross-result bookkeeping.

## How the three behaviours collapse

- **On-demand**: the consumer `shift`s its buffer (or `await`s its completion)
  and blocks until the reader delivers — there's no separate synchronous path,
  just an empty buffer.
- **Prefetch**: the dedicated reader fills each result's buffer toward its
  high-water mark and refills past the low-water mark — *real* background
  prefetch (server fetch + decode overlap the consumer's work), not just
  round-trip hiding. The eager first `PULL` rides with `RUN`; `PULL` #2+ are
  watermark-gated, so a result nobody reads is filled once and then **left alone**
  — never force-drained, which is exactly the `tx_run prevent_*` fix.
- **qid-multiplexing**: each open result holds its own completions and buffer;
  the FIFO routes replies by arrival order; `qid` rides only on the *outgoing*
  `PULL`/`DISCARD` to tell the server which result. `tx.run` stops force-draining
  the previous result — it tracks a set of open results; commit/rollback
  `DISCARD`s each by qid; termination fans out (above). This retires `tx_run`
  `prevent_pull_*` / `prevent_discard_*` and `iteration` `test_nested`.

## Connection & reader lifecycle

**One concurrency model per *active* connection — for free.** The pool hands a
connection to one lessee at a time, and a session/transaction isn't safe to drive
from multiple threads, so a checked-out connection is always used in exactly one
concurrency context. We don't impose this as a contract — the pool's
single-lessee semantics guarantee it. So the reader is chosen to **match the
current window at acquire**, and within a window the reader and the consumer are
always the *same color* (both threads, or both fibers on one thread). The
cross-thread→fiber hand-off therefore never arises.

**Executor by scheduler; lifetime by what that executor can safely outlive:**

- **Threaded host (no `Fiber.scheduler`) → reader = a Thread, connection-lifetime.**
  A thread has no reactor coupling, so it can live for the connection's pooled
  life: spawned on the first thread-mode acquire, it fills buffers while checked
  out and **parks on the idle socket between checkouts** (reused on the next
  acquire — no per-checkout spawn). Parked on the socket it also sees a
  server-side close as EOF, so it **retires the `broken?` peek** the on-demand
  design needed.
- **Reactor host (`Fiber.scheduler` present) → reader = a fiber, active-window.**
  A fiber is reactor-lifetime-coupled: a forever-looping driver fiber would stop
  the host's `Async{}`/request block from exiting (structured concurrency waits
  for it) and would be orphaned across reactor contexts — with no way, through the
  core scheduler interface, to detect teardown or mark it transient. So the fiber
  reader is `Fiber.schedule`d at acquire and **completes at release**, always
  inside the reactor context that spawned it. (Idle pooled connections under a
  reactor thus have no reader and keep the `broken?` peek.)

**Close and model-transition share one mechanism.** A parked reader blocks in
`wait_readable`, so stopping it — at `connection.close` *or* when an acquire's
model differs from the parked reader's — needs an out-of-band wakeup: the reader
waits on the socket **and** a control pipe; close/stop writes the pipe. A
transition is then *stop the old reader → spawn the matching one → same socket,
same wire/FIFO state* — it **keeps the authenticated socket** (the expensive
asset; reconnect costs a TCP + handshake + HELLO/LOGON round-trip set) and never
reconnects. At acquire the connection is quiescent (no in-flight work), so the
swap is clean.

**One pool, no segregation.** A connection is one type with a swappable reader
attachment — not a thread-class and a fiber-class — and the pool stays
model-agnostic. Separate pools would double routing/auth/liveness bookkeeping and
fragment capacity (a warm thread-connection couldn't serve a fiber acquire) to
"help" only the rare mixed-model app, which the cheap in-place swap already
covers. So a pooled connection is either *thread-reader-parked* or *bare* (its
last fiber reader completed, or it was never used), and acquire adapts the reader
to the caller. Single-model apps (the norm) never swap: Falcon runs all-fibers
with no driver threads; Puma runs all-threads with a persistent per-connection
reader and no `broken?` probe.

## What it retires / keeps

- **Retire:** `Connection#fetch_response` + `@inbox`/`@collector` (callers now
  `enqueue`/`await`); `Result#promote` and the promote/buffer-shift dual path;
  `Executor.reactor?`'s role as a *per-stream* mode switch.
- **Generalise:** `Bolt::Pump` + `Bolt::Executor` + `Bolt::RecordSource` become
  the connection's one dedicated reader (the pump, now filling *all* the
  connection's result buffers; the executor choice moves to acquire-time per the
  lifecycle above; the source's `pull(n)`/`discard(n)` gain a `qid`).
- **Keep:** `Bolt::Wire` (already the FIFO router — gains completions);
  `RecordBuffer` **with its watermarks** (the reader fills to high, refills past
  low); the colorless read (`fill_inbox` → `advance`) and the single
  `@write_mutex` for `flush`.
- **Public API unchanged:** session / transaction / result / pool / providers
  keep their signatures; this is an internal rework of the connection's I/O core.

## Invariants / hazards

- **One reader, guarded writer.** The connection's dedicated reader is the sole
  caller of `advance`; `flush` stays behind `@write_mutex` (a consumer may
  enqueue+flush a new request while the reader reads). Never two readers — and at
  acquire a model swap stops the old reader before starting the new one.
- **Colorless throughout.** Blocking reads via `wait_readable`; waits via stdlib
  `ConditionVariable`. No `async`-gem types; the driver consumes a host
  `Fiber.scheduler` if present, never installs one. Preserves mri-on-jruby
  (threads) and falls back cleanly when JRuby's scheduler is absent/incomplete.
- **Failure fan-out is all-or-nothing.** A broken connection must fail every
  queued completion exactly once, then refuse new `enqueue`s with a classified
  `ServiceUnavailableException` (today's `send_message`-when-closed contract).
- **Quiesce before pool return.** On early `close`/cancel, `DISCARD` open results
  and drain to their terminals (or `RESET`) so a returned connection never
  carries a half-read stream or an unfulfilled completion.
- **Pure-Ruby I/O precondition** for the fiber path (a C-extension reading the
  socket would bypass the scheduler) — our transport is pure Ruby.

## Migration (each step its own validation pass; full stub suite is the gate)

1. **Completions under the wire.** Add `enqueue → completion` + `advance` +
   `await` to `Connection`, implemented over the existing wire FIFO. Re-express
   `fetch_response` as `await` of a single-collector completion — behaviour
   identical, no caller changes. Full stub suite green (touches every op).
2. **Dedicated reader + cursor on buffers.** Generalise `Pump`/`Executor`/
   `RecordSource` into the connection's one dedicated reader (chosen by scheduler,
   lifetime per the lifecycle section); `Result` consumes its `RecordBuffer`
   (watermark-filled by the reader) instead of `fetch_response`; drop
   `Result#promote`. Re-validate streaming + the reactor (fiber-reader) path.
3. **Failure fan-out.** A broken/terminated connection fails all outstanding
   completions; `Transaction` termination rides this. Picks up the `tx_run`
   `prevent_*` sibling-result cases.
4. **qid-multiplexing.** Capture `qid` per result; thread it onto
   `PULL`/`DISCARD`; `tx.run` tracks multiple open results; commit/rollback
   `DISCARD`s each. Picks up `iteration` `test_nested` and the rest of
   `prevent_pull_*` / `prevent_discard_*`.

Each step is independently shippable and gated on the rust-boltstub stub suite
(MRI flavor, ruby-3.4.9) plus mri-on-jruby, with the per-flavor baseline as the
regression guard — same loop as #396/#397.
