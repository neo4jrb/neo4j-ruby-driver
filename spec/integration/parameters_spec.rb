# frozen_string_literal: true

RSpec.describe 'ParametersSpec' do
  shared_examples 'original type' do |hash|
    it "should set and return a #{hash[:type]} value #{hash[:value]}" do
      driver.session do |session|
        result = session.run('CREATE (a {value:{value}}) RETURN a.value', value: hash[:value])
        expect(result.next['a.value']).to eq(hash[:value])
      end
    end
  end

  shared_examples 'original hash type' do |hash|
    it "should set and return a #{hash[:type]} hash value #{hash[:value]}" do
      driver.session do |session|
        result = session.run('CREATE (a {value:{value}.v}) RETURN a.value', value: hash[:value])
        expect(result.next['a.value']).to eq(hash[:value][:v])
      end
    end
  end

  it_behaves_like 'original type', type: 'boolen', value: true

  it_behaves_like 'original type', type: 'integer', value: 100

  it_behaves_like 'original type', type: 'float', value: 68.54

  it_behaves_like 'original type', type: 'string', value: ''

  it_behaves_like 'original type', type: 'string', value: "π≈3.14"

  it_behaves_like 'original type', type: 'string', value: "Mjölnir"

  it_behaves_like 'original type', type: 'string', value: '*** Hello World! ***'

  it_behaves_like 'original type', type: 'string', value: 'π≈3.14'

  it_behaves_like 'original type', type: 'boolean array', value: [true, false, true]

  it_behaves_like 'original type', type: 'integer array', value: [100, 12, 5]

  it_behaves_like 'original type', type: 'float array', value: [68.54, 12.3, 5.879]

  it_behaves_like 'original type', type: 'string array', value: %w[Foo Chunky Bacon]

  it_behaves_like 'original hash type', type: 'boolen', value: { v: true }

  it_behaves_like 'original hash type', type: 'integer', value: { v: 999 }

  it_behaves_like 'original hash type', type: 'float', value: { v: 54.34 }

  it_behaves_like 'original hash type', type: 'string', value: { v: 'Foo' }

  it 'throws meaningful error on setting invalid parameter type' do
    driver.session do |session|
      expect { session.run('anything', k: Object.new) }.to raise_error
    end
  end

  # it 'should throw meaningful error on setting invalid parameter type directly' do
  #   driver.session do |session|
  #   error_message = 'The parameters should be provided as Hash type. Unsupported parameters type: Object'
  #     expect { session.run('anything', Object.new) }.to raise_error(Exception, error_message)
  #   end
  # end

  # it 'should accept stream as query parameter' do
  #   driver.session do |session|
  #     expect { session.run('RETURN $value', value: stream) }.to eq(stream)
  #   end
  # end
end
