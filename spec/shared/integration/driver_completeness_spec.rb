# frozen_string_literal: true

RSpec.describe 'Driver completeness' do
  describe '#verify_authentication', version: '>=5' do
    it 'returns true for the same credentials passed explicitly' do
      good = Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password)
      expect(driver.verify_authentication(good)).to be(true)
    end

    # verify_authentication returns false only for an AuthenticationException;
    # Memgraph rejects wrong credentials with a ClientException (as the Java driver
    # does), which propagates instead of yielding false.
    it 'returns false for wrong credentials without disturbing the driver', memgraph: false do
      bad = Neo4j::Driver::AuthTokens.basic(neo4j_user, 'definitely-not-the-password')
      expect(driver.verify_authentication(bad)).to be(false)

      # And the driver is still usable afterwards (the probe was a
      # one-shot connection that didn't touch the pool).
      expect { driver.session { |s| s.run('RETURN 1').consume } }.not_to raise_error
    end
  end

  describe '#supports_session_auth?' do
    it 'is true against a Bolt 5.1+ server', version: '>=5.1' do
      expect(driver.supports_session_auth?).to be(true)
    end
  end
end
