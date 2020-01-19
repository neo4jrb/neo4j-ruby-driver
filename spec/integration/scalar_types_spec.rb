# frozen_string_literal: true

RSpec.describe 'ScalarTypesSpec' do
  [
    1,
    1.1,
    ["'hello'", 'hello'],
    true,
    false,
    ["[1,2,3]", [1, 2, 3]],
    ["['hello']", ['hello']],
    ['[]', []],
    ["{k:'hello'}", { k: 'hello' }]
  ].each do |value, exppected_value|
    it "handles type #{value}" do
      driver.session do |session|
        result = session.run("RETURN #{value} as v")
        expect(result.single['v']).to eq(exppected_value || value)
      end
    end
  end

  [nil, 1, 1.1, 'hello', true].each do |value|
    it "echos very long hash of #{value.class}" do
      hash = Array.new(1000) { |i| [i.to_s.to_sym, value] }.to_h
      verify_can_encode_and_decode(hash)
    end

    it "echos very long list of #{value.class}" do
      verify_can_encode_and_decode(Array.new(1000, value))
    end
  end

  it 'echos very long string' do
    verify_can_encode_and_decode('*' * 10_000)
  end

  [
    nil,
    true,
    false,
    1,
    -17,
    -129,
    129,
    2_147_483_647,
    -2_147_483_648,
    -13_244_323_234,
    9_223_372_036_854_775_807,
    -9_223_372_036_854_775_808,
    1.7976931348623157E+308,
    2.2250738585072014e-308,
    0.0,
    1.1,
    '1',
    '-17∂ßå®',
    'String',
    ''
  ].each do |value|
    it "echos scalar types #{value.inspect}" do
      verify_can_encode_and_decode(value)
    end
  end

  list_to_test = [
    [1, 2, 3, 4],
    [true, false],
    [1.1, 2.2, 3.3],
    ['a', 'b', 'c', '˚C'],
    [nil, nil],
    [nil, true, '-17∂ßå®', 1.7976931348623157E+308, -9_223_372_036_854_775_808],
    [{ a: 1, b: true, c: 1.1, d: '˚C', e: nil }]
  ]

  list_to_test.each do |list|
    it "echos list #{list}" do
      verify_can_encode_and_decode(list)
    end
  end

  it 'echos nested list' do
    verify_can_encode_and_decode(list_to_test)
  end

  hash_to_test = [
    { a: 1, b: 2, c: 3, d: 4 },
    { a: true, b: false },
    { a: 1.1, b: 2.2, c: 3.3 },
    { b: 'a', c: 'b', d: 'c', e: '˚C' },
    { a: nil },
    { a: 1, b: true, c: 1.1, d: '˚C', e: nil }
  ]

  hash_to_test.each do |hash|
    it "echos hash #{hash}" do
      verify_can_encode_and_decode(hash)
    end
  end

  it 'echos nested hash' do
    verify_can_encode_and_decode(hash_to_test.map { |hash| [hash.to_s.to_sym, hash] }.to_h)
  end

  def verify_can_encode_and_decode(var)
    driver.session do |session|
      result = session.run('RETURN $x as y', x: var)
      expect(result.single[:y]).to eq(var)
    end
  end
end
