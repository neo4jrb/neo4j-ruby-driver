# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Ext::VectorConverter do
  Neo4j::Driver::Types::Vector::ELEMENT_TYPES.each_key do |element_type|
    it "round-trips a #{element_type} vector through the Java driver's Vector" do
      vector = Neo4j::Driver::Types::Vector.new(element_type, [1, -1, 0])
      java_vector = described_class.to_java(vector)

      expect(java_vector).to be_a(Java::OrgNeo4jDriverTypes::Vector)
      expect(java_vector.length).to eq(3)
      expect(java_vector.to_array.to_a).to eq([1, -1, 0])
      expect(described_class.to_ruby(java_vector)).to eq(vector)
    end
  end

  it 'keeps float bits exact, including a signalling NaN payload' do
    vector = Neo4j::Driver::Types::Vector.from_bytes(:float32, "\x7f\x88\x42\x25\x3f\x80\x00\x00".b)

    expect(described_class.to_ruby(described_class.to_java(vector)).data).to eq(vector.data)
  end
end
