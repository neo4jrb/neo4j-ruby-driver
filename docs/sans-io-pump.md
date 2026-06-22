# MRI Bolt::Connection — sans-I/O core + pluggable pump

Status: **in progress** (2026-06-22). Alternative to the Async-reactor design
(`docs/pipelined-connection.md` / PR #395). Motivation and the full design
rationale are in `async_vs_threads.md` (the design conversation); this doc is the
implementer's summary.

## Why this instead of the Async reactor

The reactor design made `lib/mri/` depend on the `async` gem, which is
unsupported on JRuby (no native `IO_Event` selector; `IO#timeout`/scheduler
don't fire; the reactor hangs). That forced dropping the **mri-on-jruby** test
flavor. This design depends only on **Ruby core + stdlib**, so:

- It runs on plain threads by default (works on CRuby *and* JRuby → mri-on-jruby
  is restored).
- It is *also* reactor-compatible for free, with **no `async` dependency**: under
  a host Fiber scheduler (Falcon, or any `Async {}`), Ruby's own blocking socket
  I/O auto-yields via the scheduler's `io_wait`, and the stdlib
  `Queue`/`SizedQueue`/`Mutex`/`ConditionVariable` are scheduler-aware. The
  driver is a scheduler **consumer**, never a provider — it never installs a
  reactor, so it imposes no concurrency model on the host.

A driver should not pick the host's concurrency model. Build neutral (blocking
I/O on a thread-safe pool); serve threaded hosts by default and async hosts for
free.

## Layers

1. **Sans-I/O Bolt core — `Bolt::Wire`.** A pure state machine, *no socket*:
   - `enqueue(message)` packs + chunk-frames into an outbound byte buffer;
   - `take_outbound` hands those bytes to whoever owns the socket;
   - `receive(bytes)` feeds inbound bytes and returns fully-parsed messages
     (RECORD / SUCCESS / FAILURE / IGNORED) in order, reassembling chunks across
     calls, skipping NOOP keepalives, and retaining partial data.
   Fully unit-testable without a network, and identical regardless of how I/O is
   driven. Owns the chunk framing, NOOP handling, and PackStream hydration.

2. **Bounded record buffer + watermarks — `Bolt::RecordBuffer`.** Holds decoded
   records for one stream, tracks the consumed count, and owns the *autopull
   policy*: enqueue the next `PULL {n: fetch_size}` when buffered drops below the
   low watermark and `has_more`; withhold at the high watermark. Hysteresis (high
   ≈ 1–2× fetch_size, low a fraction) so PULLs aren't thrashed. A `SizedQueue`
   bound provides driver→consumer backpressure.

3. **The pump (the only concurrency-aware part).** Moves bytes both directions:
   read socket → `wire.receive` → route records into the buffer; `wire.take_outbound`
   → write socket. Single reader, writes guarded by one mutex.
   - **On-demand** (default, zero extra threads): runs on the consumer's thread;
     a read happens when `next` empties the buffer.
   - **Prefetch** (opt-in, true background): runs on its own `Executor` —
     `Thread` by default, a fiber via `Fiber.schedule` when `Fiber.scheduler` is
     present — filling the buffer to the high watermark ahead of demand. Same
     pump body; blocking reads auto-yield under a scheduler.

4. **Cursor / result API** on top — `next`/`each`/`peek`/`close` — popping from
   the buffer, pacing PULLs, blocking on empty until the pump fills or the stream
   ends. Owns the pump's lifecycle and the checked-out connection.

## Concurrency model

- **Per active streaming result** (≡ per connection — a Bolt connection carries
  one ordered stream at a time). Bolt replies are strictly ordered per socket, so
  there is exactly one reader. Not per-client-thread (binds to the wrong
  resource); not a shared selector (that's a reactor — the escalation, gated on a
  measured thread-count problem, not the default).
- **Threaded host:** the prefetch pump is a thread bound to the connection's
  *pooled lifetime* — lazily spawned on first streaming use, parked between
  streams (blocked on a control queue, touching nothing), torn down only on
  eviction/pool-close. Avoids `Thread.new`/join on the hot path. (A simpler
  per-checkout create/destroy is acceptable but leaves throughput on the table.)
- **Reactor host:** the pump is a fiber via `Fiber.schedule`, spawned fresh per
  stream and discarded on exhaustion (fibers are cheap; no parking apparatus). Or
  drop the separate pump entirely and pipeline in-fiber (keep a PULL in flight,
  read lazily in the consumer fiber). Mode is chosen once, at stream start, by
  `Fiber.scheduler` — the *only* concurrency-mode-aware check in the driver.

## Invariants / hazards

- **One reader, guarded writer** per socket — the consumer thread may also write
  (new query, DISCARD), so writes go behind one mutex; never two readers.
- **Quiesce before pool return:** on early `close`, send `DISCARD` and drain to
  the stream boundary (or `RESET`) before the connection goes back to the pool,
  so the next checkout never gets a connection with a rogue reader mid-socket.
- **Pure-Ruby I/O is a precondition** for the reactor path: a C-extension doing
  its own socket reads would bypass `io_wait` and freeze the reactor. Our
  transport is pure Ruby.
- **Cancellation/errors in the stdlib fiber pump are cooperative:** stop via a
  sentinel on the control queue; stash a pump exception and re-raise it in the
  consumer on its next `next`.

## Build order

1. `Bolt::Wire` + unit tests (this commit).
2. `Bolt::RecordBuffer` + watermark autopull.
3. Pump + `Executor` (on-demand; Thread/fiber prefetch).
4. Rewire `Bolt::Connection` onto the core + pump; cursor lifecycle. Preserve the
   public `Connection` API so session/transaction/result/pool/providers are
   untouched.
5. Validate: full rust-boltstub stub suite on CRuby (zero regressions vs main)
   and mri-on-jruby green; restore the mri-on-jruby CI rows.
