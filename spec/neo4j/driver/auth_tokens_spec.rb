# frozen_string_literal: true

RSpec.describe Neo4j::Driver::AuthTokens do
  describe '.basic' do
    it 'does not allow nil username' do
      expect { described_class.basic(nil, 'password') }.to raise_error ArgumentError, "Username can't be nil"
    end

    it 'does not allow nil password' do
      expect { described_class.basic('username', nil) }.to raise_error ArgumentError, "Password can't be nil"
    end
  end
end
