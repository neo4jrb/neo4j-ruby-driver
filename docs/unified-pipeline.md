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
3. `await(completion)` — drive `advance` until *this* completion is fulfilled,
   then return its value (or raise its stored error).

"Synchronous" is just `enqueue(msg).then { await(it) }`. Every request is async;
`await` is the thin, colorless blocking layer on top. No `async` gem; the only
concurrency primitives are stdlib `Mutex`/`ConditionVariable`, which are
scheduler-aware.

### Single reader, many waiters (the crux)

Responses are strictly ordered per socket, so there must be exactly **one reader
at a time** — but any thread/fiber may be the one waiting. The rule: whoever
needs a reply and finds no active reader *becomes* the reader and pumps for
**everyone** (each reply lands in its own completion via the FIFO); everyone else
parks until a reader fulfils them.

```
def await(completion)
  @mutex.synchronize do
    until completion.ready? || @reader.nil?
      @cv.wait(@mutex)          # someone else is reading; park
    end
    return take(completion) if completion.ready?
    @reader = Fiber.current     # claim the reader role
  end

  begin
    until completion.ready?
      advance                   # blocking read OUTSIDE @mutex (colorless)
      @mutex.synchronize { @cv.broadcast }  # let parked waiters re-check
    end
  ensure
    @mutex.synchronize { @reader = nil; @cv.broadcast }  # hand off the role
  end
  take(completion)
end
```

The **leader hand-off** is the correctness keystone: on exit the reader clears
the role and broadcasts, so a still-waiting fiber either finds its completion
already fulfilled (returns) or becomes the next reader. There is never an
unfulfilled completion with no reader and no one about to become one — so no
deadlock, and no thundering herd (followers don't touch the socket). The
blocking read happens *outside* `@mutex`, so under a scheduler the reader fiber
yields and the followers' `@cv.wait` yields too.

This is the #395 reactor's "reader fiber + handler FIFO + mailboxes" idea —
minus the dedicated reactor thread and the `async` gem. The reactor is *whoever
is currently awaiting*.

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

- **On-demand**: `await(enqueue(pull))`. The consumer is the reader; it pumps
  until its record arrives.
- **Prefetch (keep-one-ahead)**: before processing batch *N*, enqueue the `PULL`
  for batch *N+1* (when buffer capacity allows). Its round-trip overlaps the
  consumer's work on batch *N*; the next `await` finds it already in flight or
  arrived. **No background thread.** This alone removes `Bolt::Pump`,
  `Bolt::Executor`, `RecordSource`, and the `Executor.reactor?` JRuby special
  case. (A background filler that just calls `advance` for CPU-bound consumers
  remains *possible* as an add-on — but it's another driver of the same pump, not
  a separate path, and is deferred until a measured need.)
- **qid-multiplexing**: each open result holds its own completions and buffer;
  the FIFO routes replies by arrival order; `qid` rides only on the *outgoing*
  `PULL`/`DISCARD` to tell the server which result. `tx.run` stops force-draining
  the previous result — it tracks a set of open results; commit/rollback
  `DISCARD`s each by qid; termination fans out (above). This retires `tx_run`
  `prevent_pull_*` / `prevent_discard_*` and `iteration` `test_nested`.

## What it retires / keeps

- **Retire:** `Connection#fetch_response` + `@inbox`/`@collector`; `Bolt::Pump`;
  `Bolt::Executor` (+ its JRuby reactor guard); `Bolt::RecordSource`;
  `Result#promote` and the promote/buffer-shift dual path.
- **Keep / evolve:** `Bolt::Wire` (already the FIFO router — gains completions);
  `RecordBuffer` becomes a plain per-result record queue (backpressure via its
  bound) fed by that result's completions; `Connection`'s colorless read
  (`fill_inbox` → `advance`) and the single `@write_mutex` for `flush`.
- **Public API unchanged:** session / transaction / result / pool / providers
  keep their signatures; this is an internal rework of the connection's I/O core.

## Invariants / hazards

- **One reader at a time, guarded writer.** The leader hand-off above enforces
  the reader; `flush` stays behind `@write_mutex` (a follower may enqueue+flush a
  new request while the leader reads). Never two readers.
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
2. **Cursor on completions.** `Result` reads via `await` of its result's
   completions instead of `fetch_response`; keep-one-ahead pipelining replaces
   `Pump`/promotion. Delete `Pump`/`Executor`/`RecordSource`. Re-validate
   streaming + the prefetch reactor behaviour (now just pipelining under a host
   scheduler).
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
