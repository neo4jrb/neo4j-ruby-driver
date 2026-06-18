# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Driver do
  # MRI-only — exercises the pure-Ruby Driver wrapper directly. The JRuby
  # flavor delegates encrypted? to the Java driver.
  next unless Neo4j::Driver::Loader.mri?

  # connection_provider is unused by #encrypted?, so a nil is fine here.
  def make_driver(uri, **options) = described_class.new(uri, options, nil)

  describe '#encrypted?' do
    it 'is false for plain bolt:// with no encryption option' do
      expect(make_driver('bolt://localhost')).not_to be_encrypted
    end

    it 'is true for the +s / +ssc schemes' do
      expect(make_driver('bolt+s://localhost')).to be_encrypted
      expect(make_driver('neo4j+ssc://localhost')).to be_encrypted
    end

    # Regression: #encrypted? read the wrong option key (:encrypted) while the
    # rest of the driver — TlsConfig, the public API, the testkit backend —
    # uses :encryption, so an explicitly-encrypted driver reported false.
    it 'is true when :encryption is explicitly set, even on bolt://' do
      expect(make_driver('bolt://localhost', encryption: true)).to be_encrypted
    end

    it 'is false when :encryption is explicitly false' do
      expect(make_driver('bolt://localhost', encryption: false)).not_to be_encrypted
    end
  end
end
