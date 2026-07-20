# frozen_string_literal: true

# A +s / +ssc scheme already fixes the security plan (encrypted; plus
# trust-all for +ssc). Combining it with *manually configured* encryption or
# trust settings is a conflict — both flavours raise a ClientException whose
# message mentions encryption and trust (MRI:
# DriverFactory#validate_security_settings; JRuby: the Java driver's
# SecurityPlans). Value equality (Detail:DefaultSecurityConfigValueEquality):
# a setting whose value equals the driver default (encryption off; trust =
# system certificates) is treated as not configured, so it is not a conflict.
RSpec.describe Neo4j::Driver::GraphDatabase do
  # Construction is lazy (no connection until first use), so these assert the
  # security-config validation without touching the server.
  def build(uri, **config)
    described_class.driver(uri, Neo4j::Driver::AuthTokens.none, **config).close
  end

  conflict = Neo4j::Driver::Exceptions::ClientException
  message = /is not configurable with manual encryption and trust settings/

  context 'with a +s / +ssc scheme' do
    it 'raises when encryption is explicitly enabled' do
      expect { build('neo4j+s://localhost', encryption: true) }.to raise_error(conflict, message)
      expect { build('bolt+ssc://localhost', encryption: true) }.to raise_error(conflict, message)
    end

    it 'raises when a non-default trust strategy is set' do
      expect { build('neo4j+s://localhost', trust_strategy: { strategy: :trust_all_certificates }) }
        .to raise_error(conflict, message)
      expect do
        build('neo4j+s://localhost',
              trust_strategy: { strategy: :trust_custom_certificates, cert_files: ['/tmp/x'] })
      end.to raise_error(conflict, message)
    end

    it 'accepts encryption explicitly disabled (equals the default)' do
      expect { build('neo4j+s://localhost', encryption: false) }.not_to raise_error
    end

    it 'accepts an explicit system-certificates trust strategy (equals the default)' do
      expect { build('neo4j+s://localhost', trust_strategy: { strategy: :trust_system_certificates }) }
        .not_to raise_error
    end

    it 'accepts a bare +s / +ssc scheme with no security config' do
      expect { build('neo4j+s://localhost') }.not_to raise_error
      expect { build('bolt+ssc://localhost') }.not_to raise_error
    end
  end

  context 'with a plain bolt / neo4j scheme' do
    it 'accepts manual encryption and trust settings' do
      expect { build('bolt://localhost', encryption: true) }.not_to raise_error
      expect { build('neo4j://localhost', trust_strategy: { strategy: :trust_all_certificates }) }
        .not_to raise_error
    end
  end
end
