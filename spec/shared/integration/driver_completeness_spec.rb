# frozen_string_literal: true

RSpec.describe 'Driver completeness' do
  describe '#server_info' do
    it 'returns the negotiated agent, address and protocol version' do
      info = driver.server_info

      expect(info).to be_a(Neo4j::Driver::Summary::ServerInfo)
      expect(info.agent).to match(%r{\ANeo4j/})
      expect(info.address).to include(':')      # host:port
      expect(info.protocol_version).to match(/\A\d+\.\d+\z/)
    end
  end

  describe '#verify_authentication' do
    it 'returns true for the driver default auth' do
      expect(driver.verify_authentication).to be(true)
    end

    # JRuby's Java driver enforces Bolt 5.1+ for explicit-token
    # verify_authentication and raises UnsupportedFeatureException on
    # older servers. MRI doesn't gate this (it opens a one-shot
    # connection that authenticates inside HELLO at <5.1), but to
    # keep the cross-flavour spec passing we match Java's bar.
    context 'with an explicit token (Bolt 5.1+ servers)', version: '>=5' do
      it 'returns true for the same credentials passed explicitly' do
        good = Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password)
        expect(driver.verify_authentication(good)).to be(true)
      end

      it 'returns false for wrong credentials without disturbing the driver' do
        bad = Neo4j::Driver::AuthTokens.basic(neo4j_user, 'definitely-not-the-password')
        expect(driver.verify_authentication(bad)).to be(false)

        # And the driver is still usable afterwards (the probe was a
        # one-shot connection that didn't touch the pool).
        expect { driver.session { |s| s.run('RETURN 1').consume } }.not_to raise_error
      end
    end
  end

  describe '#supports_session_auth?' do
    it 'is true against a Bolt 5.1+ server', version: '>=5.1' do
      expect(driver.supports_session_auth?).to be(true)
    end
  end
end
