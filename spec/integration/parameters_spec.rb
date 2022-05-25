# frozen_string_literal: true


RSpec.describe 'Parameters' do
  let(:session) { driver.session }
  after(:example) { session.close }

  def test_property(value, &block)
    block ||= ->(out_value) { out_value.is_a? value.class }
    session.run(query, value: parameter_processor(value)).each do |record|
      out_value = record['a.value']
      expect(block.call(value)).to be true
      expect(out_value).to eq value
    end
  end

  context "is able to set and return property" do
    let(:query) { 'CREATE (a {value: $value}) RETURN a.value' }

    def parameter_processor(value)
      value
    end

    it 'is able to set and return Boolean property' do
      test_property true
    end

    # skiped, no such types in ruby
    # shouldBeAbleToSetAndReturnByteProperty
    # shouldBeAbleToSetAndReturnShortProperty

    it 'Integer' do
      test_property 1
    end

    # skiped, no such types in ruby
    # shouldBeAbleToSetAndReturnLongProperty

    it 'is able to set and return Float property' do
      test_property 6.28
    end

    it 'is able to set and return ByteArray property' do
      proc = ->(v) { v.is_a?(String) && v.encoding == Encoding::BINARY }
      bytes = ->(size) { Random.new.bytes(size, &proc) }
      test_property bytes.call(0)
      16.times do |i|
        length = 2 ** i
        test_property bytes.call(length)
        test_property bytes.call(length - 1)
      end
    end

    # skipped, do not support neo4j older than 3.4
    # shouldThrowExceptionWhenServerDoesNotSupportBytes

    it 'is able to set and return String property' do
      test_property ''
      test_property 'π≈3.14'
      test_property 'Mjölnir'
      test_property '*** Hello World! ***'
    end

    it 'is able to set and return Boolean Array property' do
      test_property [true, true, true]
    end

    it 'is able to set and return Integer Array property' do
      test_property [42, 42, 42]
    end

    it 'is able to set and return Float Array property' do
      test_property [6.28, 6.28, 6.28]
    end

    it 'is able to set and return String Array property' do
      test_property ['cat'] * 3
      test_property ['Mjölnir'] * 3
    end
  end

  it 'handles large strings' do
    big_string = 'abcd' * 2560
    expect(session.run('RETURN $p AS p', p: big_string).peek[:p]).to eq big_string
  end

  context 'is able to set and return property within map' do
    let(:query) { 'CREATE (a {value: $value.v}) RETURN a.value' }

    def parameter_processor(value)
      { v: value }
    end

    it 'Boolean' do
      test_property true
    end

    it 'Integer' do
      test_property 42
    end

    it 'Float' do
      test_property 6.28
    end

    it 'String' do
      test_property 'Mjölnir'
    end
  end

  context 'invalid parameter types' do
    let(:value_query) { 'CREATE (u) RETURN u' }
    let(:value) { session.run(value_query).single.first }

    shared_examples 'raises exception' do
      specify do
        expect { session.run('RETURN $a', a: value).consume }
          .to raise_error Neo4j::Driver::Exceptions::ClientException,
                          /^Unable to convert #{value.class.name} to Neo4j Value./
      end
    end

    context 'setting invalid parameter type throws helpful error' do
      let(:value) { Object.new }

      it_behaves_like 'raises exception'
    end

    it 'setting invalid parameter type directly throws helpful error' do
      expect { session.run('anything', value) }
        .to raise_error ArgumentError,
                        /^The parameters should be provided as Map type. Unsupported parameters type: .*Node/
    end

    context 'is not possible to use Node as parameter in map value' do
      it_behaves_like 'raises exception'
    end

    context 'is not possible to use Relationship as parameter in map value' do
      let(:value_query) { 'CREATE ()-[r:KNOWS]->() RETURN r' }
      it_behaves_like 'raises exception'
    end

    context 'is not possible to use Path as parameter in map value' do
      let(:value_query) { 'CREATE p=() RETURN p' }
      it_behaves_like 'raises exception'
    end
  end

  context 'long values' do
    LONG_VALUE_SIZE = 1_000_000

    subject do
      session.run('RETURN $value', value: value).single[0]
    end

    context 'sends and receives long string' do
      let(:value) { FFaker::Lorem.characters(LONG_VALUE_SIZE) }

      it { is_expected.to eq value }
    end

    context 'sends and receives long list of longs' do
      let(:value) do
        MAX_INTEGER = 2 ** 63 - 1
        Array.new(LONG_VALUE_SIZE) { rand(MAX_INTEGER) }
      end

      it { is_expected.to eq value }
    end

    context 'sends and receives long array of bytes' do
      let(:value) { Random.new.bytes(LONG_VALUE_SIZE) }

      it { is_expected.to eq value }
    end
  end

  it 'accepts streams as query parameters' do
    stream = Class.new do
      include Enumerable

      def each
        yield 1
        yield 2
        yield 3
        yield 4
        yield 5
        yield 42
      end
    end.new

    received_value = session.run('RETURN $value', value: stream).single[0]
    expect(received_value).to eq [1, 2, 3, 4, 5, 42]
  end
end
