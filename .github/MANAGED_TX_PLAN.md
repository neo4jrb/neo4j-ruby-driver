# Managed transactions — implementation plan

Tracking the work behind this PR so the design is reviewable before the
code lands.

## Why

Testkit's `SessionExecuteRead` / `SessionExecuteWrite` requests are the
single biggest cluster of unimplemented backend behaviour: 63 of the
69 currently-erroring testkit tests hit
`UnknownTypeError: No handler for request SessionReadTransaction` (or
its write twin). Implementing them lets dozens of datatype, summary,
and transaction tests actually run.

## The shape of the protocol

When testkit's frontend calls `session.execute_read(work)`, it sends:

1. `SessionReadTransaction { sessionId, txMeta, timeout }`

The backend must reply **`RetryableTry { sessionId, txId }`** rather
than a normal terminating response. From this point on, testkit sends
operations against `txId`:

2. `TransactionRun { txId, cypher, params }` → backend replies `Result { ... }`
3. `ResultNext { resultId }` → `Record` / `NullRecord`
4. ...any other `Transaction*` / `Result*` requests...

Eventually testkit emits one of:

- **`RetryablePositive { sessionId }`** — work succeeded; backend should
  commit the transaction and respond with the original
  `Session { sessionId }` response (closing out the original
  `SessionReadTransaction` request).
- **`RetryableNegative { sessionId, errorId }`** — work failed; backend
  should let the driver know (via raising inside the block), allowing
  the driver's retry logic to fire (`RetryableTry` again with a new
  `txId`) or surface a final failure.

## The shape of the implementation

The current `Connection` runs a flat loop:

```ruby
while (req = read_request)
  write_response(Request.dispatch(req, @registry))
end
```

A `SessionReadTransaction` handler can't return a normal response —
it needs to:

1. Invoke `session.execute_read { |tx| ... }`.
2. **Inside** the block:
   a. Store `tx` in the registry under a freshly-minted `tx_id`.
   b. Write a `RetryableTry { sessionId, txId }` response upstream.
   c. Enter a **nested dispatch loop** that reads more requests and
      writes their responses, continuing until a `RetryablePositive`
      or `RetryableNegative` arrives.
   d. On `RetryablePositive`: break out of the loop normally (the
      driver's `execute_read` then commits the tx and returns).
   e. On `RetryableNegative`: raise an exception inside the block so
      the driver's retry path fires.
3. After `session.execute_read` returns: write the terminating
   `Session { sessionId }` response and we're done.

Driver-side, `Session#execute_read/write` already retries
`ServiceUnavailableException` / `TransientException` via
`execute_transaction`. We may need to teach it about an additional
exception class (something like a `Backend::RetryableNegative` we'd
raise inside the block) and make sure that exception propagates back
out as something testkit recognises.

## What needs to change

- `Connection` exposes `read_request` and `write_response` so request
  handlers can drive their own nested loops (or accept a `Conversation`
  object that wraps them).
- `Request.dispatch` (or a new helper) is callable from inside a
  handler — currently dispatch is only called from `Connection.run`.
- `Request.new` gains a `connection:` (or `conversation:`) kwarg.
  `Request#initialize` strips that alongside `registry:` so it doesn't
  appear in `Data.define` field declarations.
- New request classes:
  - `SessionExecuteRead`
  - `SessionExecuteWrite`
  - `RetryablePositive` (consumed inside the nested loop, not from the
    top-level loop)
  - `RetryableNegative` (same)
- New response class:
  - `RetryableTry { session_id, tx_id }`
- `Registry` may need a way to remove the tx after the block returns
  (driver already commits/closes it; backend's bookkeeping just needs
  to drop the handle).
- A small driver-side hook so we can raise a typed exception from
  inside the block that `execute_transaction` treats as
  retryable / non-retryable based on what testkit sent.

## What probably *doesn't* change

- The Registry abstraction stays single-typed.
- The Cypher conversion layer stays as-is.
- The Response Mixin stays as-is — `RetryableTry` is just another
  Data.define.

## Walk-down expectation

Once this lands, testkit baseline rises by ≈40-60 (rough estimate).
Some of those will pass directly; some will fail for the *next* reason
in line (graph types, summary fields). We'll re-baseline and iterate.
