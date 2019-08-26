# frozen_string_literal: true

RSpec.describe 'ScalarTypesSpec' do
  shared_examples 'scalar type' do |value, exppected_value|
    it "should return #{value}" do
      driver.session do |session|
        result = session.run("RETURN #{value} as v")
        expect(result.next['v']).to eq(exppected_value || value)
      end
    end
  end

  shared_examples 'scalar hash type' do |value|
    it "should echo very long hash of #{value.class}" do
      hash = 1000.times.collect { |i| [i.to_s.to_sym, value]}.to_h
      encode_decode_value(hash)
    end
  end

  shared_examples 'scalar array type' do |value|
    it "should echo very long array of #{value.class}" do
      encode_decode_value(Array.new(1000, value))
    end
  end


  # respective java spec shouldHandleType
  it_behaves_like 'scalar type', 1

  it_behaves_like 'scalar type', -1

  it_behaves_like 'scalar type', 1.1

  # long interger not supported yet
  #it_behaves_like 'scalar type', 9223372036854775808

  it_behaves_like 'scalar type', "'Hello'", 'Hello'

  it_behaves_like 'scalar type', true

  it_behaves_like 'scalar type', false

  it_behaves_like 'scalar type', [1, 2, 3], [1, 2, 3]

  it_behaves_like 'scalar type', ['Hello'], ['Hello']

  it_behaves_like 'scalar type', [], []

  it_behaves_like 'scalar type', {}

  it_behaves_like 'scalar type', "{k: 'Hello'}", k: 'Hello'

  
  # shouldEchoVeryLongMap
  it_behaves_like 'scalar hash type', nil

  it_behaves_like 'scalar hash type', 9223

  # long interger not supported yet
  # it_behaves_like 'scalar hash type', 9223372036854775808

  it_behaves_like 'scalar hash type', 1.999

  it_behaves_like 'scalar hash type', 'Hello'

  it_behaves_like 'scalar hash type', true

  
  # shouldEchoVeryLongList
  it_behaves_like 'scalar array type', nil

  it_behaves_like 'scalar array type', 9223

  # long interger not supported yet
  # it_behaves_like 'scalar array type', 9223372036854775808

  it_behaves_like 'scalar array type', 1.999

  it_behaves_like 'scalar array type', 'Hello'

  it_behaves_like 'scalar array type', true

  it 'echos very long string' do
    encode_decode_value('*' * 10000)
  end

  [
    nil,
    true,
    false,
    1,
    -17,
    -129,
    129,
    2147483647,
    -2147483648,
    -13244323234,
    9223372036854775807,
    -9223372036854775808,
    1.7976931348623157E+308,
    2.2250738585072014e-308,
    0.0,
    1.1,
    '1',
    '-17∂ßå®',
    'String',
    ''
  ].each do |value|
    it "should echo scalar types #{value}" do
      encode_decode_value(value)
    end
  end

  [
    [1, 2, 3, 4],
    [true, false],
    [1.1, 2.2, 3.3],
    ['a', 'b', 'c', '˚C'],
    [nil, nil],
    [nil, true, '-17∂ßå®', 1.7976931348623157E+308, -9223372036854775808]
    #ListValue( parameters( "a", 1, "b", true, "c", 1.1, "d", "˚C", "e", null ) )
  ].each do |list|
    it 'echos list' do
      encode_decode_value(list)
    end
  end

  # it 'echos nested list' do

  # end

  [
     { a: 1, b: 2, c: 3, d: 4 },
     { a: true, b: false },
     { a: 1.1, b: 2.2, c: 3.3 },
     { b: 'a', c: 'b', d: 'c', e: '˚C'},
     { a: nil },
     { a: 1, b: true, c: 1.1, d: '˚C', e: nil }
  ].each do |hash|
    it "echos hash #{hash}" do
      encode_decode_value(hash)
    end
  end

  # it 'should echo nested hash' do
    
  # end

  def encode_decode_value(var)
    driver.session do |session|
      result = session.run( 'RETURN {x} as y', x: var)
      expect(result.next['y']).to eq(var)
    end
  end
end
