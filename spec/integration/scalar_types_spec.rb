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

  it_should_behave_like 'scalar type', 1

  it_should_behave_like 'scalar type', 1.1

  it_should_behave_like 'scalar type', "'Hello'", 'Hello'

  it_should_behave_like 'scalar type', true

  it_should_behave_like 'scalar type', false

  it_should_behave_like 'scalar type', [1, 2, 3], [1, 2, 3]

  it_should_behave_like 'scalar type', ['Hello'], ['Hello']

  it_should_behave_like 'scalar type', [], []

  it_should_behave_like 'scalar type', {}

  it_should_behave_like 'scalar type', "{k: 'Hello'}", { k: 'Hello' }
end
