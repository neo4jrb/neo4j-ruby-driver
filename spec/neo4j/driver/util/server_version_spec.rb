RSpec.describe Neo4j::Driver::Internal::Util::ServerVersion do
  context 'when', RUBY_PLATFORM: 'ruby' do
    context 'Version' do
      it 'should match server version' do
        expect(Neo4j::Driver::Internal::Util::ServerVersion.version("Neo4j/dev")).to eq(Neo4j::Driver::Internal::Util::ServerVersion::V_IN_DEV)
        expect(Neo4j::Driver::Internal::Util::ServerVersion.version("Neo4j/4.0.0")).to eq(Neo4j::Driver::Internal::Util::ServerVersion::V4_0_0)
      end
    end

    it 'should have correct string' do
      expect("Neo4j/dev").to eq(Neo4j::Driver::Internal::Util::ServerVersion::V_IN_DEV.to_s)
      expect("Neo4j/4.0.0").to eq(Neo4j::Driver::Internal::Util::ServerVersion::V4_0_0.to_s)
      expect("Neo4j/3.5.0").to eq(Neo4j::Driver::Internal::Util::ServerVersion::V3_5_0.to_s)
      expect("Neo4j/3.5.7").to eq(Neo4j::Driver::Internal::Util::ServerVersion.version("Neo4j/3.5.7").to_s)
    end

    it 'should fail to parse illegal versions' do
      expect{ Neo4j::Driver::Internal::Util::ServerVersion.version("") }.to raise_error(ArgumentError)
      expect{ Neo4j::Driver::Internal::Util::ServerVersion.version("/1.2.3") }.to raise_error(ArgumentError)
      expect{ Neo4j::Driver::Internal::Util::ServerVersion.version("Neo4j1.2.3") }.to raise_error(ArgumentError)
      expect{ Neo4j::Driver::Internal::Util::ServerVersion.version("Neo4j") }.to raise_error(ArgumentError)
    end

    it 'should fail to compare different products' do
      version1 = Neo4j::Driver::Internal::Util::ServerVersion.version("MyNeo4j/1.2.3")
      version2 = Neo4j::Driver::Internal::Util::ServerVersion.version("OtherNeo4j/1.2.4")

      expect{ version1 >= version2 }.to raise_error(ArgumentError)
    end

    it 'should return correct server version from bolt protocol version' do
      expect(Neo4j::Driver::Internal::Util::ServerVersion::V4_0_0).to eq(Neo4j::Driver::Internal::Util::ServerVersion.from_bolt_protocol_version(Neo4j::Driver::Internal::Messaging::V4::BoltProtocolV4::VERSION))
      expect(Neo4j::Driver::Internal::Util::ServerVersion::V4_1_0).to eq(Neo4j::Driver::Internal::Util::ServerVersion.from_bolt_protocol_version(Neo4j::Driver::Internal::Messaging::V41::BoltProtocolV41::VERSION))
      expect(Neo4j::Driver::Internal::Util::ServerVersion::V4_2_0).to eq(Neo4j::Driver::Internal::Util::ServerVersion.from_bolt_protocol_version(Neo4j::Driver::Internal::Messaging::V42::BoltProtocolV42::VERSION))
      expect(Neo4j::Driver::Internal::Util::ServerVersion::V4_3_0).to eq(Neo4j::Driver::Internal::Util::ServerVersion.from_bolt_protocol_version(Neo4j::Driver::Internal::Messaging::V43::BoltProtocolV43::VERSION))
      expect(Neo4j::Driver::Internal::Util::ServerVersion::V4_4_0).to eq(Neo4j::Driver::Internal::Util::ServerVersion.from_bolt_protocol_version(Neo4j::Driver::Internal::Messaging::V44::BoltProtocolV44::VERSION))
      expect(Neo4j::Driver::Internal::Util::ServerVersion::V_IN_DEV).to eq(Neo4j::Driver::Internal::Util::ServerVersion.from_bolt_protocol_version(Neo4j::Driver::Internal::Messaging::BoltProtocolVersion.new(java.lang.Integer::MAX_VALUE, java.lang.Integer::MAX_VALUE)))
    end
  end
end