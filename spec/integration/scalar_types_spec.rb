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
      run_spec(hash)
    end
  end

  shared_examples 'scalar array type' do |value|
    it "should echo very long array of #{value.class}" do
      run_spec(Array.new(1000, value))
    end
  end


  it_behaves_like 'scalar type', 1

  it_behaves_like 'scalar type', -1

  it_behaves_like 'scalar type', 1.1

  # it_behaves_like 'scalar type', 9223372036854775808

  it_behaves_like 'scalar type', "'Hello'", 'Hello'

  it_behaves_like 'scalar type', true

  it_behaves_like 'scalar type', false

  it_behaves_like 'scalar type', [1, 2, 3], [1, 2, 3]

  it_behaves_like 'scalar type', ['Hello'], ['Hello']

  it_behaves_like 'scalar type', [], []

  it_behaves_like 'scalar type', {}

  it_behaves_like 'scalar type', "{k: 'Hello'}", k: 'Hello'

  it_behaves_like 'scalar hash type', nil

  it_behaves_like 'scalar hash type', 9223

  # it_behaves_like 'scalar hash type', 9223372036854775808

  it_behaves_like 'scalar hash type', 1.999

  it_behaves_like 'scalar hash type', 'Hello'

  it_behaves_like 'scalar hash type', true

  it_behaves_like 'scalar array type', nil

  it_behaves_like 'scalar array type', 9223

  # it_behaves_like 'scalar array type', 9223372036854775808

  it_behaves_like 'scalar array type', 1.999

  it_behaves_like 'scalar array type', 'Hello'

  it_behaves_like 'scalar array type', true

  [nil, true, false, 1123423423, -13244323234, 1.2343234234, 'Hello', '', '1' , { k: 'Hello' }, { k: { a: 1 } }].each do |value|
    it "should encode decode #{value}" do
      run_spec(value)
    end
  end

  def run_spec(var)
    driver.session do |session|
      result = session.run( 'RETURN {x} as y', x: var)
      expect(result.next['y']).to eq(var)
    end
  end
end
