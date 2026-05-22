# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Bolt::TlsConfig do
  # MRI-only — TlsConfig builds an OpenSSL::SSL::SSLContext, which the
  # JRuby flavor doesn't go through (Java driver owns its own TLS path).
  next unless Neo4j::Driver::Loader.mri?

  def config(uri, **options) = described_class.new(uri: URI(uri), options:)

  describe '#encrypted?' do
    it 'is false for plain bolt://' do
      expect(config('bolt://localhost')).not_to be_encrypted
    end

    it 'is true for bolt+s://' do
      expect(config('bolt+s://localhost')).to be_encrypted
    end

    it 'is true for bolt+ssc://' do
      expect(config('bolt+ssc://localhost')).to be_encrypted
    end

    it 'is true for neo4j+s:// and neo4j+ssc://' do
      expect(config('neo4j+s://localhost')).to be_encrypted
      expect(config('neo4j+ssc://localhost')).to be_encrypted
    end

    it 'is true when :encryption is explicitly true even with bolt://' do
      expect(config('bolt://localhost', encryption: true)).to be_encrypted
    end
  end

  describe '#ssl_context' do
    it 'returns nil for plaintext schemes' do
      expect(config('bolt://localhost').ssl_context).to be_nil
    end

    it 'returns a context with VERIFY_PEER for +s' do
      # OpenSSL::SSL::SSLContext has no reader for min_version, so we
      # can't introspect it post-hoc — that's covered by the integration
      # path (TLS 1.0 / 1.1 fixtures fail to handshake). What we can
      # check here is that the basic shape is right.
      ctx = config('bolt+s://localhost').ssl_context
      expect(ctx).to be_a(OpenSSL::SSL::SSLContext)
      expect(ctx.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it 'returns a VERIFY_NONE context for +ssc' do
      ctx = config('bolt+ssc://localhost').ssl_context
      expect(ctx.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'honours explicit :trust_all_certificates option over +s scheme' do
      ctx = config('bolt+s://localhost',
                   trust_strategy: { strategy: :trust_all_certificates }).ssl_context
      expect(ctx.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'raises when :trust_custom_certificates is set without cert_files' do
      expect do
        config('bolt+s://localhost',
               trust_strategy: { strategy: :trust_custom_certificates }).ssl_context
      end.to raise_error(ArgumentError, /at least one path in :cert_files/)
    end

    it 'raises on an unknown trust_strategy strategy' do
      expect do
        config('bolt+s://localhost',
               trust_strategy: { strategy: :trust_nothing }).ssl_context
      end.to raise_error(ArgumentError, /Unknown trust_strategy/)
    end
  end

  describe '#verify_hostname?' do
    it 'is false for plaintext' do
      expect(config('bolt://localhost')).not_to be_verify_hostname
    end

    it 'is true for +s (system certs)' do
      expect(config('bolt+s://localhost')).to be_verify_hostname
    end

    it 'is false for +ssc (trust-all by default)' do
      expect(config('bolt+ssc://localhost')).not_to be_verify_hostname
    end

    it 'is false when trust-all is set explicitly even on +s' do
      expect(config('bolt+s://localhost',
                    trust_strategy: { strategy: :trust_all_certificates })).not_to be_verify_hostname
    end
  end
end
