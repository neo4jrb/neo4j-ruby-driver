# frozen_string_literal: true

# Bolt 5.1+ per-session auth: each session.acquire issues LOGOFF /
# LOGON to switch identity on the pooled connection, then sessions
# without :auth re-authenticate back to the driver's stored token —
# so the pool never bleeds auth identity across users.
RSpec.describe 'Per-session auth', version: '>=5.1' do
  let(:driver_auth) { Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password) }

  it 'runs queries on a session opened with an explicit token equal to the driver auth' do
    driver.session(auth_token: driver_auth) do |s|
      expect(s.run('RETURN 1 AS n').single[:n]).to eq(1)
    end
  end

  it 'rejects a wrong token with AuthenticationException at first use' do
    bad = Neo4j::Driver::AuthTokens.basic(neo4j_user, 'definitely-not-the-password')
    expect do
      driver.session(auth_token: bad) { |s| s.run('RETURN 1').consume }
    end.to raise_error(Neo4j::Driver::Exceptions::AuthenticationException)
  end

  it "doesn't poison the pool — subsequent default sessions still work" do
    bad = Neo4j::Driver::AuthTokens.basic(neo4j_user, 'definitely-not-the-password')
    expect do
      driver.session(auth_token: bad) { |s| s.run('RETURN 1').consume }
    end.to raise_error(Neo4j::Driver::Exceptions::AuthenticationException)

    expect(driver.session { |s| s.run('RETURN 42 AS n').single[:n] }).to eq(42)
  end
end
