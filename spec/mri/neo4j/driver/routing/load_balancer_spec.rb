# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Routing::LoadBalancer do
  next unless Neo4j::Driver::Loader.mri?

  # Lock-order regression tests. TimedStack#pop runs the connect factory
  # while holding the pool mutex, and release/refresh take that mutex under
  # @refresh_lock, so the connect factory must never take @refresh_lock.
  #
  # Fake Bolt::Connection: the surface LoadBalancer and Bolt::Pool touch,
  # plus a `gate` the test uses to hold a chosen `connect` open.
  let(:protocol) do
    Class.new do
      def supports_re_auth? = false
      def version = '5.0'
    end.new
  end

  let(:connection_class) do
    proto = protocol
    Class.new do
      attr_accessor :idle_since, :created_at, :auth_epoch, :session_scoped_auth,
                    :security_exception_handler, :on_close, :discard_on_release
      attr_reader :auth, :uri

      define_method(:protocol) { proto }

      def initialize(uri, auth, gate)
        @uri = uri
        @auth = auth
        @gate = gate
        @auth_epoch = 0
      end

      def connect(**)
        @gate&.call(@uri)
        @created_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        self
      end

      def route(database: nil, **)
        { ttl: 1000, db: database || 'neo4j',
          servers: [{ addresses: ['server:7687'], role: 'ROUTE' },
                    { addresses: ['server:7687'], role: 'READ' },
                    { addresses: ['server:7687'], role: 'WRITE' }] }
      end

      def reset!(**) = nil
      def alive? = true
      def broken? = false
      def closed? = false
      def close = nil
      def ssr_enabled? = false
      def authenticate(*, **) = nil
    end
  end

  let(:auth_manager) { instance_double(Neo4j::Driver::Internal::InternalAuthTokenManager, get_token: { scheme: 'basic' }) }
  let(:balancer) { described_class.new(URI('neo4j://server:7687'), auth_manager, {}) }

  # Hold the Nth connect open: signal `connecting`, then wait for `proceed`.
  def gate_holding_connect(nth, connecting, proceed)
    count = 0
    lambda do |_uri|
      count += 1
      next unless count == nth

      connecting << :connecting
      proceed.pop
    end
  end

  def stub_connections(gate)
    klass = connection_class
    allow(Neo4j::Driver::Bolt::Connection).to receive(:new) { |uri, auth, *| klass.new(uri, auth, gate) }
  end

  # The thread must be parked (on the pool mutex the opener holds) and still
  # unfinished while the gate is closed; otherwise the race isn't set up.
  def wait_until_blocked(thread)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    sleep 0.01 until thread.status == 'sleep' || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    expect(thread.status).to eq('sleep')
    expect(thread.join(0.1)).to be_nil
  end

  # Both scenarios start the same way: one acquire does discovery (connect #1,
  # reused as the worker connection and checked out), so the next worker
  # acquire must open connect #2 — inside TimedStack#pop, holding its mutex.
  def checked_out_connection_and_blocked_opener(connecting, proceed)
    stub_connections(gate_holding_connect(2, connecting, proceed))
    held = balancer.acquire(access_mode: :write, database: 'neo4j')
    opener = Thread.new { balancer.acquire(access_mode: :write, database: 'neo4j') }
    expect(connecting.pop(timeout: 2)).to eq(:connecting), 'the second acquire never reached connect'
    [held, opener]
  end

  it 'does not deadlock when a release races a connection being opened to the same server' do
    connecting = Queue.new
    proceed = Queue.new
    held, opener = checked_out_connection_and_blocked_opener(connecting, proceed)

    releaser = Thread.new { balancer.release(held) }
    wait_until_blocked(releaser)
    proceed << :go

    expect(releaser.join(2)).not_to be_nil, 'release is stuck behind a thread opening a connection'
    expect(opener.join(2)).not_to be_nil, 'acquire is stuck opening a connection'
  ensure
    [releaser, opener].compact.each(&:kill)
  end

  it 'bumps the auth epoch of the reporting server only, on AuthorizationExpired' do
    server = Neo4j::Driver::Routing::ServerAddress.parse('server:7687')
    other = Neo4j::Driver::Routing::ServerAddress.parse('other:7687')
    allow(auth_manager).to receive(:handle_security_exception).and_return(false)
    error = Neo4j::Driver::Exceptions::AuthorizationExpiredException.new(
      'expired', code: 'Neo.ClientError.Security.AuthorizationExpired'
    )

    balancer.on_security_exception(server, { scheme: 'basic' }, error)

    expect(balancer.auth_epoch_for(server)).to eq(1)
    expect(balancer.auth_epoch_for(other)).to eq(0)
  end

  it 'does not deadlock when a routing refresh races a connection being opened to the same server' do
    connecting = Queue.new
    proceed = Queue.new
    _held, opener = checked_out_connection_and_blocked_opener(connecting, proceed)

    refresher = Thread.new { balancer.refresh('neo4j') }
    wait_until_blocked(refresher)
    proceed << :go

    expect(refresher.join(2)).not_to be_nil, 'routing refresh is stuck behind a thread opening a connection'
    expect(opener.join(2)).not_to be_nil, 'acquire is stuck opening a connection'
  ensure
    [refresher, opener].compact.each(&:kill)
  end
end
