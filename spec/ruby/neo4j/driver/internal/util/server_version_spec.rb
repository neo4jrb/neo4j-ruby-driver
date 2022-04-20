include Neo4j::Driver::Internal::Messaging

RSpec.describe Neo4j::Driver::Internal::Util::ServerVersion do
  it '.version' do
    expect(described_class.version('Neo4j/dev')).to eq(described_class::V_IN_DEV)
    expect(described_class.version('Neo4j/4.0.0')).to eq(described_class::V4_0_0)
  end

  it 'has correct #to_s' do
    expect(described_class::V_IN_DEV.to_s).to eq 'Neo4j/dev'
    expect(described_class::V4_0_0.to_s).to eq 'Neo4j/4.0.0'
    expect(described_class::V3_5_0.to_s).to eq 'Neo4j/3.5.0'
    expect(described_class.version('Neo4j/3.5.7').to_s).to eq 'Neo4j/3.5.7'
  end

  it 'fails to parse illegal versions' do
    expect { described_class.version('') }.to raise_error(ArgumentError)
    expect { described_class.version('/1.2.3') }.to raise_error(ArgumentError)
    expect { described_class.version('Neo4j1.2.3') }.to raise_error(ArgumentError)
    expect { described_class.version('Neo4j') }.to raise_error(ArgumentError)
  end

  it 'fails to compare different products' do
    version1 = described_class.version('MyNeo4j/1.2.3')
    version2 = described_class.version('OtherNeo4j/1.2.4')

    expect { version1 >= version2 }.to raise_error(ArgumentError)
  end

  it 'returns correct server version .from_bolt_protocol_version' do
    expect(described_class.from_bolt_protocol_version(V4::BoltProtocolV4::VERSION)).to eq described_class::V4_0_0
    expect(described_class.from_bolt_protocol_version(V41::BoltProtocolV41::VERSION)).to eq described_class::V4_1_0
    expect(described_class.from_bolt_protocol_version(V42::BoltProtocolV42::VERSION)).to eq described_class::V4_2_0
    expect(described_class.from_bolt_protocol_version(V43::BoltProtocolV43::VERSION)).to eq described_class::V4_3_0
    expect(described_class.from_bolt_protocol_version(V44::BoltProtocolV44::VERSION)).to eq described_class::V4_4_0
    expect(described_class.from_bolt_protocol_version(BoltProtocolVersion.new(nil, nil)))
      .to eq described_class::V_IN_DEV
  end
end
