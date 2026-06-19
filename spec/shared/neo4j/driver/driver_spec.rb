# frozen_string_literal: true

# Public-API behaviour of Driver#encrypted?, exercised through GraphDatabase
# so it covers both flavours (MRI's pure-Ruby Driver and JRuby's wrapper over
# Java's isEncrypted). Driver construction is lazy — these never connect.
RSpec.describe 'Neo4j::Driver::Driver#encrypted?' do
  def build_driver(uri, **config)
    Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.none, **config)
  end

  it 'is false for a plain bolt:// URI with no encryption option' do
    driver = build_driver('bolt://localhost')
    expect(driver.encrypted?).to be false
  ensure
    driver&.close
  end

  it 'is true for the +s / +ssc schemes' do
    %w[bolt+s://localhost neo4j+ssc://localhost].each do |uri|
      driver = build_driver(uri)
      expect(driver.encrypted?).to be true
      driver.close
    end
  end

  # Regression: MRI read the wrong option key (:encrypted) while the rest of
  # the stack — TlsConfig, the testkit backend, the public API — uses
  # :encryption, so an explicitly-encrypted driver wrongly reported false.
  # JRuby (Java's isEncrypted) was always correct; this locks both.
  it 'is true when encryption is enabled via the :encryption option' do
    driver = build_driver('bolt://localhost', encryption: true)
    expect(driver.encrypted?).to be true
  ensure
    driver&.close
  end

  it 'is false when the :encryption option is explicitly false' do
    driver = build_driver('bolt://localhost', encryption: false)
    expect(driver.encrypted?).to be false
  ensure
    driver&.close
  end
end
