# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Bolt::Pool do
  next unless Neo4j::Driver::Loader.mri?

  # Fake connection that records what the pool does to it. Real
  # Bolt::Connection wraps a socket — irrelevant here; the pool's
  # contract is the four attributes plus #alive? / #closed? / #close.
  let(:connection_class) do
    Class.new do
      attr_accessor :idle_since, :created_at
      attr_reader :alive_calls, :close_calls

      def initialize(alive: true, closed: false, broken: false)
        @alive = alive
        @closed = closed
        @broken = broken
        @alive_calls = 0
        @close_calls = 0
      end

      def alive?
        @alive_calls += 1
        @alive
      end

      def broken?
        @broken
      end

      def closed?
        @closed
      end

      def close
        @close_calls += 1
        @closed = true
      end

      # Pool RESETs a connection on return; a no-op here.
      def reset!(**) = nil
    end
  end

  # Factory that hands out preconfigured connections in order. The
  # pool calls it on demand (when stack is empty / on discard) with the
  # per-acquire auth token, which these tests ignore.
  def build_pool(connections, **options)
    queue = connections.dup
    described_class.new(
      size: 8,
      options: options,
      connect_factory: ->(_auth, _deadline = nil) { queue.shift || raise('factory exhausted') }
    )
  end

  describe '#pop' do
    it 'returns the pooled connection on the hot path' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn])

      expect(pool.pop).to be(conn)
    end

    it 'clears idle_since on hand-out so a re-checkout does not re-probe' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn], connection_liveness_check_timeout: 0.001)
      pool.push(conn)
      conn.idle_since = monotonic - 1 # force "past the threshold" deterministically

      expect(pool.pop.idle_since).to be_nil
    end

    it 'discards + replaces a connection older than max_connection_lifetime' do
      old = connection_class.new
      old.created_at = monotonic - 100
      fresh = connection_class.new
      fresh.created_at = monotonic
      pool = build_pool([old, fresh], max_connection_lifetime: 1.0)

      expect(pool.pop).to be(fresh)
      expect(old.close_calls).to eq(1)
    end

    it 'probes when idle longer than connection_liveness_check_timeout, hands out if alive' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn], connection_liveness_check_timeout: 0.001)

      pool.push(conn)
      conn.idle_since = monotonic - 1

      expect(pool.pop).to be(conn)
      expect(conn.alive_calls).to eq(1)
    end

    it 'discards a dead connection on the liveness probe and replaces it' do
      # `dead` is pushed by the test directly; only `fresh` is in the
      # factory queue so the pool's replace-on-discard call doesn't
      # re-shift `dead` and double-discard it.
      dead = connection_class.new(alive: false)
      dead.created_at = monotonic
      fresh = connection_class.new
      fresh.created_at = monotonic
      pool = build_pool([fresh], connection_liveness_check_timeout: 0.001)

      pool.push(dead)
      dead.idle_since = monotonic - 1

      expect(pool.pop).to be(fresh)
      expect(dead.close_calls).to eq(1)
    end

    it 'skips the liveness probe when the threshold is not configured' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn])
      pool.push(conn)

      pool.pop

      expect(conn.alive_calls).to eq(0)
    end

    it 'discards a reused connection the server closed while idle (cheap peer-close check)' do
      # No liveness-check timeout configured, yet a reused connection whose peer
      # closed it (broken?) must still be discarded + replaced — without a RESET
      # round-trip (alive? not consulted).
      stale = connection_class.new(broken: true)
      stale.created_at = monotonic
      fresh = connection_class.new
      fresh.created_at = monotonic
      pool = build_pool([fresh])

      pool.push(stale)
      stale.idle_since = monotonic

      expect(pool.pop).to be(fresh)
      expect(stale.close_calls).to eq(1)
      expect(stale.alive_calls).to eq(0) # cheap check, no RESET probe
    end

    it 'raises ClientException after the acquisition timeout elapses on a full pool' do
      pool = described_class.new(
        size: 1,
        options: { connection_acquisition_timeout: 0.05 },
        connect_factory: ->(_auth, _deadline = nil) { connection_class.new.tap { |c| c.created_at = monotonic } }
      )
      pool.pop # exhaust the single slot

      expect { pool.pop }.to raise_error(
        Neo4j::Driver::Exceptions::ClientException,
        /Unable to acquire connection from the pool/
      )
    end
  end

  describe '#discard' do
    it 'closes the connection and frees the slot so a fresh one can be created' do
      bad = connection_class.new
      bad.created_at = monotonic
      fresh = connection_class.new
      fresh.created_at = monotonic
      # size: 1 makes the slot accounting observable — without
      # decrement_created the second pop would block / time out.
      sequence = [bad, fresh].each
      pool = described_class.new(
        size: 1,
        options: { connection_acquisition_timeout: 0.5 },
        connect_factory: ->(_auth, _deadline = nil) { sequence.next }
      )
      pool.pop # `bad` is now the checked-out one
      pool.discard(bad)

      expect(pool.pop).to be(fresh)
      expect(bad.close_calls).to eq(1)
    end
  end

  describe '#push' do
    it 'stamps idle_since with monotonic time' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn])
      pool.pop
      before = monotonic
      pool.push(conn)

      expect(conn.idle_since).to be_a(Numeric)
      expect(conn.idle_since).to be >= before
    end

    it 'is a no-op for nil (mirrors Direct provider tolerance)' do
      pool = build_pool([])
      expect { pool.push(nil) }.not_to raise_error
    end
  end

  describe '#metrics_snapshot' do
    it 'starts at zero in_use and idle' do
      expect(build_pool([]).metrics_snapshot).to eq([0, 0])
    end

    it 'counts a popped connection as in use, then idle after push' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn])

      pool.pop
      expect(pool.metrics_snapshot).to eq([1, 0]) # in use, none idle

      pool.push(conn)
      expect(pool.metrics_snapshot).to eq([0, 1]) # returned, now idle

      pool.pop
      expect(pool.metrics_snapshot).to eq([1, 0]) # re-checked-out, not double-counted
    end

    it 'drops a checked-out connection from both counters on discard' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn])
      pool.pop

      pool.discard(conn)
      expect(pool.metrics_snapshot).to eq([0, 0])
    end

    it 'drops a connection replaced during pop (liveness) from created' do
      dead = connection_class.new(alive: false)
      dead.created_at = monotonic
      fresh = connection_class.new
      fresh.created_at = monotonic
      sequence = [dead, fresh].each
      pool = described_class.new(
        size: 2,
        options: { connection_liveness_check_timeout: 0.001 },
        connect_factory: ->(_auth, _deadline = nil) { sequence.next }
      )
      pool.pop                     # factory builds `dead` (fresh, no probe) -> in use
      pool.push(dead)              # back to the pool, idle
      dead.idle_since = monotonic - 1

      pool.pop                     # dead fails liveness -> discard_on_pop; factory builds `fresh`
      expect(pool.metrics_snapshot).to eq([1, 0]) # only fresh, in use; dead dropped from created
    end

    it 'reports nothing live after shutdown' do
      conn = connection_class.new
      conn.created_at = monotonic
      pool = build_pool([conn])
      pool.pop

      pool.shutdown { |c| c.close }
      expect(pool.metrics_snapshot).to eq([0, 0])
    end
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
