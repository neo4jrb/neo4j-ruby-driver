# frozen_string_literal: true

# testkit's test_should_drop_connections_failing_liveness_check is skipped on
# JRuby (it observes the drop via get_connection_pool_metrics, which is blocked
# by the shaded-jar ABI clash). The liveness *behaviour* and the APIs that test
# exercises are not driver-side blocked — only the metrics observation is. This
# spec runs the same scenario against a real server to ensure the
# connection_liveness_check_timeout config and the session/transaction APIs are
# exposed and functional on both flavors. The drop itself can't be forced
# without a stub server, and observing it needs metrics, so neither is asserted.
RSpec.describe 'connection liveness checking' do
  # A dedicated driver — not the shared DriverHelper#driver — so the liveness
  # config applies and we don't disturb the suite-wide driver/cleaning hook.
  let(:liveness_driver) do
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token,
                                        connection_liveness_check_timeout: 0)
  end

  after { liveness_driver.close }

  it 'accepts the liveness config and reuses health-checked pooled connections' do
    # open five sessions/transactions at once so five distinct connections
    # land in the pool, then return them all idle
    sessions = Array.new(5) { liveness_driver.session }
    txs = sessions.map(&:begin_transaction)
    txs.each do |tx|
      tx.run('RETURN 1 AS n').to_a
      tx.commit
    end
    sessions.each(&:close)

    # re-checkout: each idle connection is liveness-probed before hand-out
    # (connection_liveness_check_timeout: 0 → always), then reused
    session = liveness_driver.session
    expect(session.run('RETURN 1 AS n').single.first).to eq(1)
    session.close
  end
end
